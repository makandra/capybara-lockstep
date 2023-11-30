module Capybara
  module Lockstep
    class Client
      include Logging
      include PageAccess

      ERROR_SNIPPET_MISSING = 'Cannot synchronize: capybara-lockstep JavaScript snippet is missing'
      ERROR_PAGE_MISSING = 'Cannot synchronize with empty page'
      ERROR_ALERT_OPEN = 'Cannot synchronize while an alert is open'
      ERROR_WINDOW_CLOSED = 'Cannot synchronize with closed window'
      ERROR_NAVIGATED_AWAY = "Browser navigated away while synchronizing"

      SYNCHRONIZED_IVAR = :@lockstep_synchronized_client

      def synchronized?
        # The synchronized flag is per-session (page == Capybara.current_session).
        # This enables tests that use more than one browser, e.g. to test multi-user interaction:
        # https://makandracards.com/makandra/474480-how-to-make-a-cucumber-test-work-with-multiple-browser-sessions
        #
        # Ideally the synchronized flag would also be per-tab, per-frame and per-document.
        # We haven't found a way to patch this into Capybara, as there does not seem to be
        # a persistent object representing a document. Capybara::Node::Document just seems to
        # be a proxy accessing whatever is the current document. The way we work around this
        # is that we synchronize before switching tabs or frames.
        value = page.instance_variable_get(SYNCHRONIZED_IVAR)

        # We consider a new Capybara session to be synchronized.
        # This will be set to false after our first visit().
        value.nil? ? true : value
      end

      def synchronized=(value)
        page.instance_variable_set(SYNCHRONIZED_IVAR, value)
      end

      def synchronize
        # If synchronization fails below we consider us unsynchronized after.
        self.synchronized = false

        # Running the synchronization script while an alert is open would close the alert,
        # most likely causing subsequent expectations to fail.
        if alert_present?
          log ERROR_ALERT_OPEN
          # Don't raise an error, this will happen in an innocent test.
          # We will retry on the next Capybara synchronize call.
          return
        end

        start_time = Util.current_seconds

        begin
          Util.with_max_wait_time(timeout) do
            message_from_js = evaluate_async_script(<<~JS)
              let done = arguments[0]
              let synchronize = () => {
                if (window.CapybaraLockstep) {
                  CapybaraLockstep.synchronize(done)
                } else {
                  done(#{ERROR_SNIPPET_MISSING.to_json})
                }
              }
              const emptyDataURL = /^data:[^,]*,?$/
              if (emptyDataURL.test(location.href) || location.protocol === 'about:') {
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
              end_time = Util.current_seconds
              ms_elapsed = ((end_time.to_f - start_time) * 1000).round
              log "Synchronized client successfully [#{ms_elapsed} ms]"
              self.synchronized = true
            end
          end
        rescue ::Selenium::WebDriver::Error::ScriptTimeoutError
          timeout_message = "Could not synchronize client within #{timeout} seconds"
          log timeout_message
          if timeout_with == :error
            raise Timeout, timeout_message
          else
            # Don't raise an error, this may happen if the server is slow to respond.
            # We will retry on the next Capybara synchronize call.
          end
        rescue ::Selenium::WebDriver::Error::UnexpectedAlertOpenError
          log ERROR_ALERT_OPEN
          # Don't raise an error, this will happen in an innocent test where a click opens an alert.
          # We will retry on the next Capybara synchronize call.
        rescue ::Selenium::WebDriver::Error::NoSuchWindowError
          log ERROR_WINDOW_CLOSED
          # Don't raise an error, this will happen in an innocent test where a click closes a window.
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
        end
      end

      private

      def unhandled_synchronize_error(e)
        Lockstep.log "#{e.class.name} while synchronizing: #{e.message}"
        raise e
      end

      def timeout
        Lockstep.timeout
      end

      def timeout_with
        Lockstep.timeout_with
      end

    end
  end
end

