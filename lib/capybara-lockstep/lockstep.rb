module Capybara
  module Lockstep
    class << self
      include Configuration
      include Logging

      attr_accessor :synchronized

      def synchronized?
        value = page.instance_variable_get(:@lockstep_synchronized)
        # We consider a new Capybara session to be synchronized.
        # This will be set to false after our first visit().
        value.nil? ? true : value
      end

      def synchronized=(value)
        page.instance_variable_set(:@lockstep_synchronized, value)
      end

      ERROR_SNIPPET_MISSING = 'Cannot synchronize: Capybara::Lockstep JavaScript snippet is missing on page'
      ERROR_PAGE_MISSING = 'Cannot synchronize before initial Capybara visit'

      def synchronize(lazy: false)
        if (lazy && synchronized?) || @synchronizing || disabled?
          return
        end

        @synchronizing = true

        log 'Synchronizing'

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
                synchronize()
              } else {
                window.addEventListener('load', synchronize)
              }
            JS

            case message_from_js
            when ERROR_PAGE_MISSING
              log(message_from_js)
              self.synchronized = false
            when ERROR_SNIPPET_MISSING
              log(message_from_js)
              self.synchronized = false
            else
              log message_from_js
              log "Synchronized successfully"
              self.synchronized = true
            end
          end
        rescue StandardError => e
          log "#{e.class.name} while synchronizing: #{e.message}"
          @synchronized = false
          raise e
        ensure
          @synchronizing = false
        end
      end

      private

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

    end

  end
end

