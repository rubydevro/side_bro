# frozen_string_literal: true

require "erb"
require "securerandom"

module SideBro
  class Web
    class Action
      include SideBro::WebHelpers

      VIEWS_PATH = File.expand_path("../../../web/views", __dir__)
      TEMPLATE_CACHE = {}

      attr_reader :env, :request, :response, :nonce

      def action
        self
      end

      def initialize(env)
        @env = env
        @request = Rack::Request.new(env)
        @response = Rack::Response.new
        @response["Content-Type"] = "text/html; charset=utf-8"
      end

      def params
        @params ||= begin
          route_params = env[SideBro::Web::Router::ROUTE_PARAMS] || {}
          request.params.merge(route_params)
        end
      end

      def session
        request.session
      end

      def flash
        @flash ||= FlashHash.new(session)
      end

      def redirect(location)
        response.redirect(location)
        throw :halt, response.finish
      end

      def halt(*resp)
        res = if resp.length == 1 && resp.first.is_a?(Integer)
          Rack::Response.new([], resp.first)
        else
          resp.first
        end
        throw :halt, res.is_a?(Array) ? res : res.finish
      end

      def json(payload)
        response["Content-Type"] = "application/json; charset=utf-8"
        response.body = [JSON.generate(payload)]
        throw :halt, response.finish
      end

      def erb(template_name)
        @nonce = SecureRandom.base64(16)
        env["side_bro.csp_nonce"] = @nonce
        response["Content-Security-Policy"] =
          "default-src 'self'; " \
          "script-src 'nonce-#{@nonce}'; " \
          "style-src 'nonce-#{@nonce}' https://fonts.googleapis.com; " \
          "font-src 'self' https://fonts.gstatic.com; " \
          "img-src 'self' data:; " \
          "connect-src 'self'"
        layout = load_template(:layout)
        content = render_template(template_name)
        response.body = [layout.result_with_hash(content: content, nonce: @nonce, action: self)]
        response.finish
      end

      def render_partial(name)
        load_template(:"_#{name}").result(binding)
      end

      private

      def render_template(name)
        load_template(name).result(binding)
      end

      def load_template(name)
        tpl = ERB.new(File.read(File.join(VIEWS_PATH, "#{name}.html.erb")), trim_mode: "-")
        return tpl unless ENV["RACK_ENV"] == "production"
        TEMPLATE_CACHE[name] ||= tpl
      end
    end

    class FlashHash
      def initialize(session)
        @session = session
        @session[:flash] ||= {}
        @read = {}
      end

      def [](key)
        @read[key] ||= @session[:flash].delete(key.to_s)
      end

      def []=(key, value)
        @session[:flash][key.to_s] = value
      end

      def any?
        @session[:flash].any?
      end
    end
  end
end
