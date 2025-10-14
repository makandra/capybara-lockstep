require 'capybara'

selenium_loaded = begin
  require 'selenium-webdriver'
  true
rescue LoadError
  false
end

cuprite_loaded = begin
  require 'capybara/cuprite'
  true
rescue LoadError
  false
end

raise LoadError, "capybara-lockstep requires either selenium-webdriver or cuprite" unless selenium_loaded || cuprite_loaded

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/module/delegation'
require 'active_support/lazy_load_hooks'

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
require_relative 'capybara-lockstep/client/selenium'
require_relative 'capybara-lockstep/client/cuprite'
require_relative 'capybara-lockstep/middleware'
