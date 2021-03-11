require 'open3'

describe Capybara::Lockstep::Helper do
  class JavaScriptSpecsFailed < StandardError; end

  it 'passes JavaScript specs' do
    stdout_str, _error_str, status = Open3.capture3('bundle exec rake jasmine:ci 2>&1')
    if status.success?
      # okay
    else
      raise JavaScriptSpecsFailed, stdout_str
    end

  end

end
