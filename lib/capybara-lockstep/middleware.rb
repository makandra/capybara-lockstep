module Capybara
  module Lockstep
    class Middleware

      def initialize(app)
        @app = app
      end

      def call(env)
        start_work
        status, headers, body = @app.call(env)
        body_proxy = Rack::BodyProxy.new(body, &method(:stop_work))
        [status, headers, body]
      end

      private

      def start_work
        Server.start_work('Server request')
      end

      def stop_work
        Server.stop_work('Server request')
      end

    end
  end
end
