module Capybara
  module Lockstep
    module Configuration

      def await_timeout
        @await_timeout || 10
      end

      def await_timeout=(seconds)
        @await_timeout = seconds
      end

      def debug?
        @debug.nil? ? false : @debug
      end

      def debug=(debug)
        @debug = debug
      end

      def enabled?
        if javascript_driver?
          @enabled.nil? ? true : @enabled
        else
          false
        end
      end

      def enabled=(enabled)
        @enabled = enabled
      end

      private

      def javascript_driver?
        driver.is_a?(Capybara::Selenium::Driver)
      end

    end
  end
end
