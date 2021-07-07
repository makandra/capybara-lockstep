module Capybara
  module Lockstep
    ERROR_SNIPPET_MISSING = 'Cannot synchronize: capybara-lockstep JavaScript snippet is missing'
    ERROR_PAGE_MISSING = 'Cannot synchronize before initial Capybara visit'
    ERROR_ALERT_OPEN = 'Cannot synchronize while an alert is open'
    ERROR_NAVIGATED_AWAY = "Browser navigated away while synchronizing"

    class << self
      include Configuration
      include Logging

      attr_accessor :synchronizing
      alias synchronizing? synchronizing

      def synchronized?
        value = page.instance_variable_get(:@lockstep_synchronized)
        # We consider a new Capybara session to be synchronized.
        # This will be set to false after our first visit().
        value.nil? ? true : value
      end

      def synchronized=(value)
        page.instance_variable_set(:@lockstep_synchronized, value)
      end

      def synchronize(lazy: false, log: nil)
        if (lazy && synchronized?) || synchronizing? || mode == :off
          return
        end

        # Allow passing a log message that is only logged
        # when we're actually synchronizing.
        if log
          self.log(log)
        end

        synchronize_now
      end

      def auto_synchronize(**options)
        if mode == :auto
          synchronize(**options)
        end
      end

      private

      def synchronize_now
        self.synchronizing = true
        self.synchronized = false

        log 'Synchronizing'

        start_time = current_seconds

        begin
          with_max_wait_time(timeout) do
            message_from_js = evaluate_async_script(<<~JS)
              let done = arguments[0]
              let synchronize = () => {
                if (window.CapybaraLockstep) {
                  CapybaraLockstep.synchronize(done)
                } else {
                  done(#{ERROR_SNIPPET_MISSING.to_json})
                }
              }
              let protocol = location.protocol
              if (protocol === 'data:' || protocol == 'about:') {
                done(#{ERROR_PAGE_MISSING.to_json})
              } else if (document.readyState === 'complete') {
                // WebDriver always waits for the `load` event after a visit(),
                // unless a different page load strategy was configured.
                synchronize()
              } else {
                window.addEventListener('load', synchronize)
              }
            JS

            case message_from_js
            when ERROR_PAGE_MISSING
              log(message_from_js)
            when ERROR_SNIPPET_MISSING
              log(message_from_js)
            else
              log message_from_js
              end_time = current_seconds
              ms_elapsed = ((end_time.to_f - start_time) * 1000).round
              log "Synchronized successfully [#{ms_elapsed} ms]"
              self.synchronized = true
            end
          end
        rescue ::Selenium::WebDriver::Error::ScriptTimeoutError
          timeout_message = "Could not synchronize within #{timeout} seconds"
          log timeout_message
          if timeout_with == :error
            raise Timeout, timeout_message
          else
            # Don't raise an error, this may happen if the server is slow to respond.
            # We will retry on the next Capybara synchronize call.
          end
        rescue ::Selenium::WebDriver::Error::UnexpectedAlertOpenError
          log ERROR_ALERT_OPEN
          # Don't raise an error, this will happen in an innocent test.
          # We will retry on the next Capybara synchronize call.
        rescue ::Selenium::WebDriver::Error::JavascriptError => e
          # When the URL changes while a script is running, my current selenium-webdriver
          # raises a Selenium::WebDriver::Error::JavascriptError with the message:
          # "javascript error: document unloaded while waiting for result".
          # We will retry on the next Capybara synchronize call, by then we should see
          # the new page.
          if e.message.include?('unload')
            log ERROR_NAVIGATED_AWAY
          else
            unhandled_synchronize_error(e)
          end
        rescue StandardError => e
          unhandled_synchronize_error(e)
        ensure
          self.synchronizing = false
        end
      end

      def unhandled_synchronize_error(e)
        log "#{e.class.name} while synchronizing: #{e.message}"
        raise e
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

      def ignoring_alerts(&block)
        block.call
      rescue ::Selenium::WebDriver::Error::UnexpectedAlertOpenError
        # no-op
      end

      def current_seconds
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

    end

  end
end

