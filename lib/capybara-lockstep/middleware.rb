module Capybara
  module Lockstep
    class Middleware

      def initialize(app)
        @app = app
      end

      def call(env)
        tag = "Server request for #{env['PATH_INFO'] || 'unknown path'}"
        Lockstep.start_work(tag)

        begin
          @app.call(env)
        ensure
          Lockstep.stop_work(tag)
        end
      end

    end
  end
end
