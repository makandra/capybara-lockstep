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
    end
  end
end
