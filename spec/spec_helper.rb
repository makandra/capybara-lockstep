require 'byebug'
require "capybara-lockstep"
require 'capybara'
require 'capybara/rspec'
require_relative 'app'

options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
  # opts.add_argument('--headless')
  opts.add_argument('--window-size=1280,1024')
end

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, capabilities: [options])
end

Capybara.default_driver = :chrome

Capybara.configure do |config|
  config.app = App
  config.server_host = 'localhost'
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include Capybara::RSpecMatchers
  config.before(:each) { App.reset }
end
