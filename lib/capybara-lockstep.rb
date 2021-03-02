require 'capybara'
require 'selenium-webdriver'
require 'active_support/core_ext/module/delegation'

module Capybara
  module Lockstep
  end
end

require_relative 'capybara-lockstep/version'
require_relative 'capybara-lockstep/error'
require_relative 'capybara-lockstep/patiently'
require_relative 'capybara-lockstep/lockstep'
require_relative 'capybara-lockstep/capybara_ext'
require_relative 'capybara-lockstep/helper'
