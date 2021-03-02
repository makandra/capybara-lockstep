module Capybara
  module Lockstep
    class << self
      include Patiently

      def await_timeout
        @await_timeout || 10
      end

      def await_timeout=(seconds)
        @await_timeout = seconds
      end

      def await_idle
        ignoring_alerts do
          # evaluate_async_script also times out after Capybara.default_max_wait_time
          with_max_wait_time(await_timeout) do
            evaluate_async_script(<<~JS)
              let done = arguments[0]
              if (window.CapybaraLockstep) {
                CapybaraLockstep.awaitIdle(done)
              } else {
                done()
              }
            JS
          end
        end
      end

      def await_initialized
        patiently(await_timeout) do
          if (reason = initializing?)
            # Raise an exception that will be retried by `patiently`
            raise Capybara::ExpectationNotMet, reason
          end
        end
      end

      def initializing?
        return unless javascript_driver?

        ignoring_alerts do
          execute_script(<<~JS)
            if (location.href.indexOf('data:') == 0) {
              return 'Waiting for initial page load'
            }

            if (document.readyState !== "complete") {
              return 'Document is loading'
            }

            // The application layouts render a <body class="initializing">.
            // The "initializing" class is removed by an Angular directive (backend)
            // or Unpoly compiler (frontend).
            if (document.querySelector('body.initializing')) {
              return 'Application code is initializing'
            }

            if (window.CapybaraLockstep && CapybaraLockstep.isBusy()) {
              return 'AJAX or event handlers are running'
            }

            return false
          JS
        end
      end

      private

      def page
        Capybara.current_session
      end

      delegate :evaluate_script, :evaluate_async_script, :execute_script, :driver, to: :page

      def javascript_driver?
        driver.is_a?(Capybara::Selenium::Driver)
      end

      def ignoring_alerts(&block)
        block.call
      rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError
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

    end

  end
end

