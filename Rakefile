# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require_relative "tasks/spec_tasks"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

begin
  require 'gemika/tasks'
rescue LoadError
  puts 'Run `gem install gemika` for additional tasks'
end
