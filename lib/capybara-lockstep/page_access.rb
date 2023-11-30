module Capybara
  module Lockstep
    module PageAccess
      def page
        Capybara.current_session
      end

      delegate :evaluate_script, :evaluate_async_script, :execute_script, :driver, to: :page

      def javascript_driver?
        driver.is_a?(Capybara::Selenium::Driver)
      end

      def alert_present?
        # Chrome 54 and/or Chromedriver 2.24 introduced a breaking change on how
        # accessing browser logs work.
        #
        # Apparently, while an alert/confirm is open, Chrome will block any requests
        # to its `getLog` API. This causes Selenium to time out with a `Net::ReadTimeout` error
        page.driver.browser.switch_to.alert
        true
      rescue Capybara::NotSupportedByDriverError, ::Selenium::WebDriver::Error::NoSuchAlertError, ::Selenium::WebDriver::Error::NoSuchWindowError
        false
      end

    end
  end
end
