module Capybara
  module Lockstep
    module PageAccess
      def page
        Capybara.current_session
      end

      delegate :evaluate_script, :evaluate_async_script, :execute_script, :driver, to: :page

      def supported_driver?
        selenium_driver? || cuprite_driver?
      end

      def alert_present?
        # Chrome 54 and/or Chromedriver 2.24 introduced a breaking change on how
        # accessing browser logs work.
        #
        # Apparently, while an alert/confirm is open, Chrome will block any requests
        # to its `getLog` API. This causes Selenium to time out with a `Net::ReadTimeout` error
        return false unless selenium_driver? # This issue is selenium-specific.

        page.driver.browser.switch_to.alert
        true
      rescue Capybara::NotSupportedByDriverError, ::Selenium::WebDriver::Error::NoSuchAlertError, ::Selenium::WebDriver::Error::NoSuchWindowError
        false
      end

      def unhandled_prompts_ignored?
        return false unless selenium_driver?

        # The capabilities were returned when the session was created, so this does not talk to the browser.
        # The behavior is either a string ("ignore") or a map by prompt type ({ "default" => "ignore" }).
        behavior = page.driver.browser.capabilities[:unhandled_prompt_behavior]

        if behavior.is_a?(Hash)
          # We don't consider "beforeUnload" prompts: the string form doesn't apply to them, WebDriver accepts them instead.
          %w[alert confirm prompt].all? do |type|
            behavior.fetch(type) { behavior['default'] } == 'ignore'
          end
        else
          behavior == 'ignore'
        end
      end

      def selenium_driver?
        defined?(Capybara::Selenium::Driver) && driver.is_a?(Capybara::Selenium::Driver)
      end

      def cuprite_driver?
        defined?(Capybara::Cuprite::Driver) && driver.is_a?(Capybara::Cuprite::Driver)
      end

    end
  end
end
