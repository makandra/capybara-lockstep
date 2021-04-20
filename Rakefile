# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec
require 'jasmine'
load 'jasmine/tasks/jasmine.rake'

begin
  require 'gemika/tasks'
rescue LoadError
  puts 'Run `gem install gemika` for additional tasks'
end
