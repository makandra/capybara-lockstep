module Capybara
  module Lockstep
    module Configuration

      def timeout
        @timeout.nil? ? Capybara.default_max_wait_time : @timeout
      end

      def timeout=(seconds)
        @timeout = seconds
      end

      def debug?
        # @debug may also be a Logger object, so convert it to a boolean
        @debug.nil? ? false : !!@debug
      end

      def debug=(debug)
        @debug = debug
        if debug
          target_prose = (is_logger?(debug) ? 'Ruby logger' : 'STDOUT')
          log "Logging to #{target_prose} and browser console"
        end

        begin
          with_max_wait_time(2) do
            page.execute_script(<<~JS)
              if (window.CapybaraLockstep) {
                CapybaraLockstep.setDebug(#{debug.to_json})
              }
            JS
          end
        rescue StandardError => e
          log "#{e.class.name} while enabling logs in browser: #{e.message}"
          # Don't fail. The next page load will include the snippet with debugging enabled.
        end

        @debug
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

      def disabled?
        !enabled?
      end

      private

      def javascript_driver?
        driver.is_a?(Capybara::Selenium::Driver)
      end

    end
  end
end
