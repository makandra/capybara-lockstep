module Capybara
  module Lockstep
    class << self
      include Patiently
      include Configuration

      def await_idle
        @delay_await_idle = false
        return unless enabled?

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
      rescue ::Selenium::WebDriver::Error::UnexpectedAlertOpenError
        log 'Cannot synchronize: Alert is open'
        @delay_await_idle = true
      end

      def await_initialized
        @delay_await_initialized = false
        @delay_await_idle = false # since we're also waiting for idle
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
      rescue ::Selenium::WebDriver::Error::UnexpectedAlertOpenError
        log 'Cannot synchronize: Alert is open'
        @delay_await_initialized = true
      end

      def catch_up
        return if @catching_up

        begin
          @catching_up = true
          if @delay_await_initialized
            log 'Retrying synchronization'
            await_initialized
          # elsif browser_made_full_page_load?
          #   log 'Browser loaded new page'
          #   await_initialized
          elsif @delay_await_idle
            log 'Retrying synchronization'
            await_idle
          end
        ensure
          @catching_up = false
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

      def browser_made_full_page_load?
        # Page change without visit()
        page.has_css?('body[data-hydrating]')
      end

      def initialize_reason
        execute_script(<<~JS)
          if (location.href.indexOf('data:') == 0) {
            return 'Requesting initial page'
          }

          if (document.readyState !== "complete") {
            return 'Document is loading'
          }

          // The application layouts render a <body data-initializing>.
          // The [data-initializing] attribute is removed by an Angular directive or Unpoly compiler (frontend).
          // to signal that all elements have been activated.
          if (document.querySelector('body[data-initializing]')) {
            return 'DOM is being hydrated'
          }

          if (window.CapybaraLockstep && CapybaraLockstep.isBusy()) {
            return 'JavaScript or AJAX requests are running'
          }

          return false
        JS
      end

      def page
        Capybara.current_session
      end

      delegate :evaluate_script, :evaluate_async_script, :execute_script, :driver, to: :page

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

