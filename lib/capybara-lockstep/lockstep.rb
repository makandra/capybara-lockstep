module Capybara
  module Lockstep
    class << self
      include Patiently
      include Configuration

      def await_idle
        return unless enabled?

        ignoring_alerts do
          # evaluate_async_script also times out after Capybara.default_max_wait_time
          with_max_wait_time(timeout) do
            message_from_js = evaluate_async_script(<<~JS)
              let done = arguments[0]
              if (window.CapybaraLockstep) {
                CapybaraLockstep.awaitIdle(done)
              } else {
                done('Cannot synchronize: Capybara::Lockstep was not included in page')
              }
            JS
            log(message_from_js)
          end
        end
      end

      def await_initialized
        return unless enabled?

        # We're retrying the initialize check every few ms.
        # Don't clutter the log with dozens of identical messages.
        last_logged_reason = nil

        patiently(timeout) do
          if (reason = initialize_reason)
            if reason != last_logged_reason
              log(reason)
              last_logged_reason = reason
            end

            # Raise an exception that will be retried by `patiently`
            raise Busy, reason
          end
        end
      end

      def idle?
        unless enabled?
          return true
        end

        result = execute_script(<<~JS)
          if (window.CapybaraLockstep) {
            return CapybaraLockstep.isIdle()
          } else {
            return 'Cannot check busy state: Capybara::Lockstep was not included in page'
          }
        JS

        if result.is_a?(String)
          log(result)
          # When the snippet is missing we assume that the browser is idle.
          # Otherwise we would wait forever.
          true
        else
          result
        end
      end

      def busy?
        !idle?
      end

      private

      def initialize_reason
        ignoring_alerts do
          execute_script(<<~JS)
            if (location.href.indexOf('data:') == 0) {
              return 'Requesting initial page'
            }

            if (document.readyState !== "complete") {
              return 'Document is loading'
            }

            // The application layouts render a <body data-hydrating>.
            // The [data-hydrating] attribute is removed by an Angular directive or Unpoly compiler (frontend).
            // to signal that all elements have been activated.
            if (document.querySelector('body[data-hydrating]')) {
              return 'DOM is being hydrated'
            }

            if (window.CapybaraLockstep && CapybaraLockstep.isBusy()) {
              return 'JavaScript or AJAX requests are running'
            }

            return false
          JS
        end
      end

      def page
        Capybara.current_session
      end

      delegate :evaluate_script, :evaluate_async_script, :execute_script, :driver, to: :page

      def ignoring_alerts(&block)
        block.call
      rescue ::Selenium::WebDriver::Error::UnexpectedAlertOpenError
        # noop
      end

      def with_max_wait_time(seconds, &block)
        old_max_wait_time = Capybara.default_max_wait_time
        Capybara.default_max_wait_time = seconds
        begin
          block.call
        ensure
          Capybara.default_max_wait_time = old_max_wait_time
        end
      end

      def log(message)
        if debug? && message.present?
          message = "[Capybara::Lockstep] #{message}"
          if @debug.respond_to?(:debug)
            # If someone set Capybara::Lockstep to a logger, use that
            @debug.debug(message)
          else
            # Otherwise print to STDOUT
            puts message
          end
        end
      end

    end

  end
end

