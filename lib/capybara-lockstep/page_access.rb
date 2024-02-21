module Capybara
  module Lockstep
    module PageAccess
      def page
        Capybara.current_session
      end

      delegate :evaluate_script, :evaluate_async_script, :execute_script, :driver, to: :page

      def javascript_driver?
        selenium_driver? || playwright_driver?
      end

      def alert_present?
        # Chrome 54 and/or Chromedriver 2.24 introduced a breaking change on how
        # accessing browser logs work.
        #
        # Apparently, while an alert/confirm is open, Chrome will block any requests
        # to its `getLog` API. This causes Selenium to time out with a `Net::ReadTimeout` error
        return false unless selenium_driver?

        page.driver.browser.switch_to.alert
        true
      rescue Capybara::NotSupportedByDriverError, ::Selenium::WebDriver::Error::NoSuchAlertError, ::Selenium::WebDriver::Error::NoSuchWindowError
        false
      end

      private

      def selenium_driver?
        defined?(Capybara::Selenium::Driver) && driver.is_a?(Capybara::Selenium::Driver)
      end

      def playwright_driver?
        defined?(Capybara::Playwright::Driver) && driver.is_a?(Capybara::Playwright::Driver)
      end

    end
  end
end
