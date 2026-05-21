# frozen_string_literal: true

require "rack"
require "rack/session"
require "securerandom"
require "yaml"

require_relative "web/router"
require_relative "web/helpers"
require_relative "web/action"
require_relative "web/application"

module SideBro
  class Web
    ASSETS_PATH = File.expand_path("../../web/assets", __dir__)

    @middlewares = []
    @translations = {}

    class << self
      attr_reader :translations

      def call(env)
        @inst ||= build
        @inst.call(env)
      end

      def use(middleware, *args, &block)
        @middlewares << [middleware, args, block]
        @inst = nil  # reset cached instance
      end

      def reset!
        @inst = nil
      end

      def register_extension(extclass, name:, tab: nil, index: nil, root_dir: nil, asset_paths: nil, cache_for: 86400)
        @extensions ||= []
        @extensions << {
          class: extclass,
          name: name,
          tab: tab,
          index: index,
          root_dir: root_dir,
          asset_paths: asset_paths,
          cache_for: cache_for
        }
        @inst = nil  # reset cached instance
      end

      def extensions
        @extensions || []
      end

      def load_locale(path)
        data = YAML.safe_load_file(path, permitted_classes: [])
        data.each do |lang, keys|
          @translations[lang.to_s] ||= {}
          @translations[lang.to_s].merge!(keys || {})
        end
      end

      private

      def build
        unless ENV.key?("SIDE_BRO_SESSION_SECRET")
          warn "[SideBro] SIDE_BRO_SESSION_SECRET is not set — sessions will reset on every server restart."
        end

        SideBro::Web.extensions.each do |ext|
          next unless ext[:root_dir]
          Dir["#{ext[:root_dir]}/locales/*.yml"].each { |f| SideBro::Web.load_locale(f) }
        end

        middlewares = @middlewares.dup
        Rack::Builder.new do
          use Rack::Session::Cookie,
            key: "_side_bro_session",
            same_site: :strict,
            secret: ENV.fetch("SIDE_BRO_SESSION_SECRET") { SecureRandom.hex(32) }

          middlewares.each do |(mw, args, blk)|
            blk ? use(mw, *args, &blk) : use(mw, *args)
          end

          run SideBro::Web::Application.new
        end
      end
    end
  end
end

# Load built-in locale files
Dir[File.expand_path("../../web/locales/*.yml", __dir__)].each do |f|
  SideBro::Web.load_locale(f)
end
