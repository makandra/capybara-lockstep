module Capybara
  module Lockstep
    class Client::Cuprite < Client

      def with_synchronization_error_handling
        yield

      rescue ::Ferrum::ScriptTimeoutError
        timeout_message = "Could not synchronize client within #{timeout} seconds"
        log timeout_message
        if timeout_with == :error
          raise Timeout, timeout_message
        else
          # Don't raise an error, this may happen if the server is slow to respond.
          # We will retry on the next Capybara synchronize call.
        end

      rescue ::Ferrum::JavaScriptError => e
        if e.message.include?('unload')
          log ERROR_NAVIGATED_AWAY
        else
          unhandled_synchronize_error(e)
        end

      rescue ::Ferrum::BrowserError => e
        if e.message.include?('Session with given id not found.')
          log ERROR_WINDOW_CLOSED
          # Don't raise an error, this will happen in an innocent test where a click closes a window.
          # We will retry on the next Capybara synchronize call.
        elsif e.message.include?("Message may have string 'sessionId' property")
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
