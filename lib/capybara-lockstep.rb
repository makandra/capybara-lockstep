require 'capybara'
begin
  require 'selenium-webdriver'
  if Selenium::WebDriver::VERSION < '4.0.0'
    raise "capybara-lockstep requires selenium-webdriver >= 4.0.0"
  end
rescue LoadError
end
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/module/delegation'

module Capybara
  module Lockstep
  end
end

require_relative 'capybara-lockstep/version'
require_relative 'capybara-lockstep/errors'
require_relative 'capybara-lockstep/util'
require_relative 'capybara-lockstep/configuration'
require_relative 'capybara-lockstep/logging'
require_relative 'capybara-lockstep/page_access'
require_relative 'capybara-lockstep/lockstep'
require_relative 'capybara-lockstep/capybara_ext'
require_relative 'capybara-lockstep/helper'
require_relative 'capybara-lockstep/server'
require_relative 'capybara-lockstep/client'
require_relative 'capybara-lockstep/middleware'
