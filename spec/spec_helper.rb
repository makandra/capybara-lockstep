require 'byebug'

# Require all drivers manually before they get required
# by capybara-lockstep to show better error feedback.
require 'selenium-webdriver'
require 'capybara/cuprite'

require "capybara-lockstep"
require 'capybara'
require 'capybara/rspec'
require "rspec/wait"
require 'active_support/dependencies/autoload'
require 'active_support/core_ext/numeric'
require 'base64'

# Load all files in spec/support
Dir["#{__dir__}/support/**/*.rb"].each { |f| require f }


RSpec.configure do |config|
  config.include Capybara::DSL
  config.include Capybara::RSpecMatchers
  config.before(:each) { App.reset }
  config.wait_timeout = 5
  config.wait_delay = 0.02
end


selenium_options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
  opts.add_argument('--headless') unless ENV['NO_HEADLESS']
  opts.add_argument('--window-size=1280,1024')
end

Capybara.register_driver :chrome_selenium do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, capabilities: [selenium_options])
end

cuprite_options = {
  window_size: [1280, 1024],
  headless: !ENV['NO_HEADLESS'],
  process_timeout: 10,
  timeout: 10
}

cuprite_ci_options = {
  browser_options: { 'no-sandbox': nil },
}

cuprite_options.merge!(cuprite_ci_options) if ENV.key?('GITHUB_ACTIONS')

Capybara.register_driver :chrome_cuprite do |app|
  Capybara::Cuprite::Driver.new(app, **cuprite_options)
end

driver = ENV.fetch("CAPYBARA_DRIVER", "selenium")
case driver
when "selenium"
  Capybara.default_driver = :chrome_selenium
when "cuprite"
  Capybara.default_driver = :chrome_cuprite
else
  raise ArgumentError, "Unknown driver: #{driver}"
end

Capybara.configure do |config|
  config.app = App
  config.server_host = '127.0.0.1'
  config.default_max_wait_time = 1
end

RSpec.configure do |config|
  config.before(:each) do
    Capybara::Lockstep.wait_tasks = nil
    Capybara::Lockstep.timeout = 5
    Capybara::Lockstep.debug = false
    Capybara::Lockstep.mode = :auto
  end
end
