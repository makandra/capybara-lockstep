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

      def debug=(value)
        @debug = value
        if value
          target_prose = (is_logger?(value) ? 'Ruby logger' : 'STDOUT')
          log "Logging to #{target_prose} and browser console"
        end

        send_config_to_browser(<<~JS)
          CapybaraLockstep.debug = #{value.to_json}
        JS

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

      def wait_tasks
        @wait_tasks
      end

      def wait_tasks=(value)
        @wait_tasks = value

        send_config_to_browser(<<~JS)
          CapybaraLockstep.waitTasks = #{value.to_json}
        JS

        @wait_tasks
      end

      def disabled?
        !enabled?
      end

      private

      def javascript_driver?
        driver.is_a?(Capybara::Selenium::Driver)
      end

      def send_config_to_browser(js)
        begin
          with_max_wait_time(2) do
            page.execute_script(<<~JS)
              if (window.CapybaraLockstep) {
                #{js}
              }
            JS
          end
        rescue StandardError => e
          log "#{e.class.name} while configuring capybara-lockstep in browser: #{e.message}"
          # Don't fail. The next page load will include the snippet with the new config.
        end
      end

    end
  end
end
