# frozen_string_literal: true

module SideBro
  class Web
    class Router
      ROUTE_PARAMS = "rack.route_params"

      def initialize
        @routes = Hash.new { |h, k| h[k] = [] }
      end

      def add(method, path, &block)
        pattern, keys = compile(path)
        @routes[method.upcase] << [pattern, keys, block]
      end

      def get(path, &block) = add("GET", path, &block)
      def post(path, &block) = add("POST", path, &block)
      def head(path, &block) = add("HEAD", path, &block)

      def match(env)
        method = env["REQUEST_METHOD"]
        path = env["PATH_INFO"]

        routes_for(method).each do |pattern, keys, block|
          next unless (m = pattern.match(path))
          env[ROUTE_PARAMS] = keys.each_with_object({}) { |k, h| h[k] = m[k] }
          return block
        end
        nil
      end

      private

      def routes_for(method)
        list = @routes[method] || []
        # HEAD falls back to GET routes
        (method == "HEAD") ? list + (@routes["GET"] || []) : list
      end

      def compile(path)
        keys = []
        pattern = path
          .gsub(%r{/\*}) { keys << "splat"; "(?<splat>.*)" }
          .gsub(%r{/:([^/]+)}) { keys << $1; "/(?<#{$1}>[^$/]+)" }
        [Regexp.new("\\A#{pattern}\\z"), keys]
      end
    end
  end
end
