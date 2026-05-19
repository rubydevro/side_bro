# frozen_string_literal: true

require "json"

module SideBro
  module WebHelpers
    QUEUE_NAME_RE = /\A[a-z_:.\-0-9]+\z/i

    def validate_queue_name!(name)
      halt(404) unless name&.match?(QUEUE_NAME_RE)
    end

    def current_path?(path)
      request.path == "#{root_path}#{path}".chomp("/")
    end

    def root_path
      # Strips trailing slash from SCRIPT_NAME so prefix is always clean
      script = request.env["SCRIPT_NAME"] || ""
      script.end_with?("/") ? script : "#{script}/"
    end

    def locale
      session[:locale] || "en"
    end

    def t(key, **opts)
      str = SideBro::Web.translations.dig(locale.to_s, key.to_s) ||
        SideBro::Web.translations.dig("en", key.to_s) ||
        key.to_s
      return str if opts.empty?
      begin
        str % opts
      rescue
        str
      end
    end

    def relative_time(time)
      return "" unless time
      secs = (Time.now - time).to_i.abs
      if secs < 60 then "#{secs}s"
      elsif secs < 3600 then "#{secs / 60}m"
      elsif secs < 86400 then "#{secs / 3600}h"
      else "#{secs / 86400}d"
      end
    end

    def format_memory(mb)
      return "–" unless mb
      (mb >= 1024) ? "%.1f GB" % (mb / 1024.0) : "#{mb} MB"
    end

    def truncate(str, len = 200)
      return str if str.nil? || str.length <= len
      "#{str[0, len]}…"
    end

    ACTIVEJOB_WRAPPER = "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"

    def job_display_class(job_hash)
      return job_hash["class"] unless job_hash["class"] == ACTIVEJOB_WRAPPER
      inner = (job_hash["args"] || []).first
      inner.is_a?(Hash) ? (inner["job_class"] || ACTIVEJOB_WRAPPER) : ACTIVEJOB_WRAPPER
    end

    def display_args(job_hash)
      raw = if job_hash["class"] == ACTIVEJOB_WRAPPER
        inner = (job_hash["args"] || []).first
        inner.is_a?(Hash) ? clean_aj_args(inner["arguments"] || []) : []
      else
        job_hash["args"] || []
      end
      truncate(JSON.generate(raw))
    rescue
      "–"
    end

    def clean_aj_args(obj)
      case obj
      when Array then obj.map { |v| clean_aj_args(v) }
      when Hash
        cleaned = obj.reject { |k, _| k.to_s.start_with?("_aj_") }
          .transform_values { |v| clean_aj_args(v) }
        cleaned.size == 1 ? cleaned.values.first : cleaned
      else obj
      end
    end

    def paginate(set, page, per_page = 25)
      total = set.size
      items = set.map { |j| j }.slice(page * per_page, per_page) || []
      [items, total]
    end

    def current_page
      page = [(params["page"] || 1).to_i - 1, 0].max
      per_page = (params["per_page"] || 25).to_i.clamp(1, 250)
      [page, per_page]
    end

    def page_slice
      page, per_page = current_page
      [page * per_page, per_page]
    end

    def rtl?
      %w[ar fa he ur].include?(locale)
    end

    def h(text)
      text.to_s
        .gsub("&", "&amp;")
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
        .gsub('"', "&quot;")
        .gsub("'", "&#39;")
    end

    def csrf_token
      session[:csrf] ||= SecureRandom.hex(16)
    end

    def number_with_delimiter(n)
      n.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
    end

    def metrics_enabled?
      Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("7.0")
    end

    def handle_job_action(set)
      action_name = params["action"]
      keys = Array(params["key"])
      keys.each do |jid|
        job = set.find { |j| j.jid == jid }
        next unless job
        case action_name
        when "retry" then job.retry
        when "delete" then job.delete
        when "kill" then job.kill if job.respond_to?(:kill)
        when "add_to_queue" then job.add_to_queue if job.respond_to?(:add_to_queue)
        end
      end
    end
  end
end
