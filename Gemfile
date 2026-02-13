# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in capybara-lockstep.gemspec
gemspec

gem 'activesupport', '~> 8.0'
gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"
gem "rspec-wait", '~> 0.0.10' # we test with Ruby 2.x, and 1.0.0 requires 3.x
gem 'sinatra'
gem 'thin' # ruby 3 does not include a webserver
gem 'puma'
gem 'byebug'
gem 'gemika'
gem 'capybara', '>= 3'
gem 'selenium-webdriver', '>= 4'
gem 'cuprite'

# The following gems were previously "default gems" (always available) and are now
# "bundled gems" (need to be explicitly required). Not all gems in our Gemfile.lock (dev only) do that yet.
# To avoid splitting the Gemfile.lock by Ruby version (gemika test setup), we instead require those
# indirect dependencies ourselves.
gem 'base64' # needed by selenium-webdriver (and potentially others)
gem 'bigdecimal' # needed by activesupport (and potentially others)
gem 'ostruct'
gem 'logger'
gem 'cgi'
