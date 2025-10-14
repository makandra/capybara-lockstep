module Capybara
  module Lockstep
    class Client::Selenium < Client

      def with_synchronization_error_handling
        yield
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
  end
end
