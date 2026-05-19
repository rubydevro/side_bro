# frozen_string_literal: true

require "sidekiq"

module SideBro
  class Web
    class Application
      SAFE_METHODS = %w[GET HEAD OPTIONS TRACE].freeze

      def initialize
        @router = SideBro::Web::Router.new
        register_routes
      end

      def call(env)
        unless SAFE_METHODS.include?(env["REQUEST_METHOD"])
          unless env["HTTP_SEC_FETCH_SITE"] == "same-origin"
            return [403, {"Content-Type" => "text/plain"}, ["Forbidden"]]
          end
        end

        block = @router.match(env)
        return [404, {"Content-Type" => "text/plain"}, ["Not Found"]] unless block

        action = SideBro::Web::Action.new(env)
        catch(:halt) do
          action.instance_exec(&block)
          action.response.finish
        end
      end

      private

      def register_routes
        @router.get("/assets/*") do
          asset_path = File.expand_path(File.join(SideBro::Web::ASSETS_PATH, params["splat"].to_s))
          unless asset_path.start_with?(SideBro::Web::ASSETS_PATH) && File.file?(asset_path)
            halt(404)
          end
          content_type = case File.extname(asset_path)
          when ".css" then "text/css"
          when ".js"  then "application/javascript"
          when ".png" then "image/png"
          when ".svg" then "image/svg+xml"
          else "application/octet-stream"
          end
          response["Content-Type"] = content_type
          response["Cache-Control"] = "private, max-age=86400"
          response.body = [File.binread(asset_path)]
          response.finish
        end

        @router.head("/") do
          Sidekiq.redis { |c| c.ping }
          response["Content-Type"] = "text/plain"
          response.body = [""]
          response.finish
        rescue => e
          [500, {"Content-Type" => "text/plain"}, [e.message]]
        end

        @router.get("/") do
          @stats = Sidekiq::Stats.new
          days = (params["days"] || 30).to_i.clamp(1, 180)
          @history = Sidekiq::Stats::History.new(days)
          erb :dashboard
        end

        @router.get("/stats") do
          stats = Sidekiq::Stats.new
          redis_info = begin
            Sidekiq.redis { |c| c.info }
          rescue
            {}
          end
          json({
            processed: stats.processed,
            failed: stats.failed,
            busy: stats.workers_size,
            enqueued: stats.enqueued,
            retries: stats.retry_size,
            scheduled: stats.scheduled_size,
            dead: stats.dead_size,
            sidekiq: Sidekiq::VERSION,
            redis: redis_info
          })
        end

        @router.get("/stats/queues") do
          queues = Sidekiq::Queue.all.each_with_object({}) do |q, h|
            h[q.name] = q.size
          end
          json(queues)
        end

        @router.get("/busy") do
          @processes = Sidekiq::ProcessSet.new.to_a
          @workers = Sidekiq::WorkSet.new.to_a
          erb :busy
        end

        @router.post("/busy") do
          if params["quiet"]
            Sidekiq::ProcessSet.new.each(&:quiet!)
          elsif params["stop"]
            Sidekiq::ProcessSet.new.each(&:stop!)
          elsif (identity = params["identity"])
            process = Sidekiq::ProcessSet.new.find { |p| p.identity == identity }
            process&.quiet! if params["quiet_process"]
            process&.stop! if params["stop_process"]
          end
          redirect "#{root_path}busy"
        end

        @router.get("/queues") do
          @queues = Sidekiq::Queue.all
          erb :queues
        end

        @router.get("/queues/:name") do
          validate_queue_name!(params["name"])
          @queue = Sidekiq::Queue.new(params["name"])
          @page, @per_page = current_page
          @total = @queue.size
          @jobs = @queue.map { |j| j }.slice(@page * @per_page, @per_page) || []
          @asc = params["direction"] != "desc"
          @jobs = @jobs.reverse unless @asc
          erb :queue
        end

        @router.post("/queues/:name") do
          validate_queue_name!(params["name"])
          q = Sidekiq::Queue.new(params["name"])
          if params["pause"]
            q.pause! if q.respond_to?(:pause!)
          elsif params["unpause"]
            q.unpause! if q.respond_to?(:unpause!)
          elsif params["clear"]
            q.clear
          end
          redirect "#{root_path}queues"
        end

        @router.post("/queues/:name/delete") do
          validate_queue_name!(params["name"])
          q = Sidekiq::Queue.new(params["name"])
          job = q.find { |j| j.jid == params["key_val"] }
          job&.delete
          redirect "#{root_path}queues/#{params["name"]}"
        end

        # Retries
        @router.get("/retries") do
          @total = Sidekiq::RetrySet.new.size
          @page, @per_page = current_page
          @jobs = Sidekiq::RetrySet.new.map { |j| j }.slice(@page * @per_page, @per_page) || []
          erb :retries
        end

        @router.post("/retries/all/:op") do
          case params["op"]
          when "retry" then Sidekiq::RetrySet.new.retry_all
          when "delete" then Sidekiq::RetrySet.new.clear
          when "kill" then Sidekiq::RetrySet.new.kill_all
          end
          redirect "#{root_path}retries"
        end

        @router.get("/retries/:key") do
          @job = Sidekiq::RetrySet.new.find { |j| j.jid == params["key"] }
          halt(404) unless @job
          erb :retry
        end

        @router.post("/retries") do
          handle_job_action(Sidekiq::RetrySet.new)
          redirect "#{root_path}retries"
        end

        # Morgue (Dead)
        @router.get("/morgue") do
          @total = Sidekiq::DeadSet.new.size
          @page, @per_page = current_page
          @jobs = Sidekiq::DeadSet.new.map { |j| j }.slice(@page * @per_page, @per_page) || []
          erb :morgue
        end

        @router.post("/morgue/all/:op") do
          case params["op"]
          when "retry" then Sidekiq::DeadSet.new.retry_all
          when "delete" then Sidekiq::DeadSet.new.clear
          end
          redirect "#{root_path}morgue"
        end

        @router.get("/morgue/:key") do
          @job = Sidekiq::DeadSet.new.find { |j| j.jid == params["key"] }
          halt(404) unless @job
          erb :dead
        end

        @router.post("/morgue") do
          handle_job_action(Sidekiq::DeadSet.new)
          redirect "#{root_path}morgue"
        end

        # Scheduled
        @router.get("/scheduled") do
          @total = Sidekiq::ScheduledSet.new.size
          @page, @per_page = current_page
          @jobs = Sidekiq::ScheduledSet.new.map { |j| j }.slice(@page * @per_page, @per_page) || []
          erb :scheduled
        end

        @router.post("/scheduled/all/:op") do
          case params["op"]
          when "delete" then Sidekiq::ScheduledSet.new.clear
          when "add_to_queue" then Sidekiq::ScheduledSet.new.each(&:add_to_queue)
          end
          redirect "#{root_path}scheduled"
        end

        @router.get("/scheduled/:key") do
          @job = Sidekiq::ScheduledSet.new.find { |j| j.jid == params["key"] }
          halt(404) unless @job
          erb :scheduled_job_info
        end

        @router.post("/scheduled") do
          handle_job_action(Sidekiq::ScheduledSet.new)
          redirect "#{root_path}scheduled"
        end

        # Metrics (Sidekiq 7+ only)
        @router.get("/metrics") do
          halt(404) unless metrics_enabled?
          require "sidekiq/metrics/query"
          @period = params["period"] || "1h"
          hours = {"1h" => 1, "8h" => 8, "24h" => 24, "72h" => 72}[@period]
          @metrics = Sidekiq::Metrics::Query.new.top_jobs(hours: hours)
          erb :metrics
        end

        @router.get("/metrics/:name") do
          halt(404) unless metrics_enabled?
          require "sidekiq/metrics/query"
          @period = params["period"] || "1h"
          hours = {"1h" => 1, "8h" => 8, "24h" => 24, "72h" => 72}[@period]
          @name = params["name"]
          @metrics = Sidekiq::Metrics::Query.new.for_job(@name, hours: hours)
          erb :metrics_for_job
        end

        @router.post("/change_locale") do
          new_locale = params["locale"].to_s.strip
          session[:locale] = new_locale if SideBro::Web.translations.key?(new_locale)
          redirect(request.env["HTTP_REFERER"] || root_path.to_s)
        end
      end
    end
  end
end
