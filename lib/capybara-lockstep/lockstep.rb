module Capybara
  module Lockstep
    class << self
      include Patiently
      include Configuration

      def await_idle
        return unless enabled?

        ignoring_alerts do
          # evaluate_async_script also times out after Capybara.default_max_wait_time
          with_max_wait_time(await_timeout) do
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

        patiently(await_timeout) do
          if (reason = initialize_reason)
            log(reason)

            # Raise an exception that will be retried by `patiently`
            raise Busy, reason
          end
        end
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

            // The application layouts render a <body class="initializing">.
            // The "initializing" class is removed by an Angular directive (backend)
            // or Unpoly compiler (frontend).
            if (document.querySelector('body.initializing')) {
              return 'Application JavaScript is initializing'
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

