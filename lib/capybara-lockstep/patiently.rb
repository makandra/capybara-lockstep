module Capybara
  module Lockstep
    # Ported from https://github.com/makandra/spreewald/blob/master/lib/spreewald_support/tolerance_for_selenium_sync_issues.rb
    module Patiently

      RETRY_ERRORS = %w[
        Capybara::ElementNotFound
        Spec::Expectations::ExpectationNotMetError
        RSpec::Expectations::ExpectationNotMetError
        Minitest::Assertion
        Capybara::Poltergeist::ClickFailed
        Capybara::ExpectationNotMet
        Selenium::WebDriver::Error::StaleElementReferenceError
        Selenium::WebDriver::Error::NoAlertPresentError
        Selenium::WebDriver::Error::ElementNotVisibleError
        Selenium::WebDriver::Error::NoSuchFrameError
        Selenium::WebDriver::Error::NoAlertPresentError
        Selenium::WebDriver::Error::JavascriptError
        Selenium::WebDriver::Error::UnknownError
        Selenium::WebDriver::Error::NoSuchAlertError
      ]

      # evaluate_script latency is ~ 0.025s
      WAIT_PERIOD = 0.03

      def patiently(timeout = Capybara.default_max_wait_time, &block)
        started = monotonic_time
        tries = 0
        begin
          tries += 1
          block.call
        rescue Exception => e
          raise e unless retryable_error?(e)
          raise e if (monotonic_time - started > timeout && tries >= 2)
          sleep(WAIT_PERIOD)
          if monotonic_time == started
            raise Capybara::FrozenInTime, "time appears to be frozen, Capybara does not work with libraries which freeze time, consider using time travelling instead"
          end
          retry
        end
      end

      private

      def monotonic_time
        # We use the system clock (i.e. seconds since boot) to calculate the time,
        # because Time.now may be frozen
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def retryable_error?(e)
        RETRY_ERRORS.include?(e.class.name)
      end

    end
  end
end
