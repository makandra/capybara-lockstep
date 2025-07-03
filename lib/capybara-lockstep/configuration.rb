module Capybara
  module Lockstep
    module Configuration

      def timeout
        @timeout.nil? ? Capybara.default_max_wait_time : @timeout
      end

      def timeout=(seconds)
        @timeout = seconds
      end

      def timeout_with
        @timeout_with.nil? ? :log : @timeout_with
      end

      def timeout_with=(action)
        @timeout_with = action&.to_sym
      end

      def debug
        @debug.nil? ? false : @debug
      end

      def debug?
        # @debug may also be a Logger object, so convert it to a boolean
        !!debug
      end

      def debug=(value)
        @debug = value
        if value
          target_prose = (is_logger?(value) ? 'Ruby logger' : 'STDOUT')
          log "Logging to #{target_prose} and browser console"
        end

        send_config_to_browser(<<~JS)
          CapybaraLockstep.debug = #{debug?.to_json}
        JS

        @debug
      end

      def mode
        if javascript_driver?
          @mode.nil? ? :auto : @mode
        else
          :off
        end
      end

      def mode=(mode)
        @mode = mode&.to_sym
      end

      def with_mode(temporary_mode, &block)
        old_mode = mode
        self.mode = temporary_mode
        block.call
      ensure
        self.mode = old_mode
      end

      def enabled=(enabled)
        case enabled
        when true
          log "Setting `Capybara::Lockstep.enabled = true` is deprecated. Set `Capybara::Lockstep.mode = :auto` instead."
          self.mode = :auto
        when false
          log "Setting `Capybara::Lockstep.enabled = false` is deprecated. Set `Capybara::Lockstep.mode = :manual` or `Capybara::Lockstep.mode = :off` instead."
          self.mode = :manual
        when nil
          # Reset to default
          self.mode = nil
        end
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

      def wait_timeout_max_delay
        @wait_timeout_max_delay
      end

      def wait_timeout_max_delay=(value)
        @wait_timeout_max_delay = value

        send_config_to_browser(<<~JS)
          CapybaraLockstep.waitTimeoutMaxDelay = #{value.to_json}
        JS

        @wait_timeout_max_delay
      end

      def after_synchronize(&callback)
        after_synchronize_callbacks << callback
      end

      private

      def after_synchronize_callbacks
        @before_synchronize_callbacks ||= []
      end

      def run_after_synchronize_callbacks
        after_synchronize_callbacks.each do |callback|
          instance_eval(&callback)
        end
      end

      def send_config_to_browser(js)
        return unless javascript_driver?

        begin
          Util.with_max_wait_time(2) do
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
