module Capybara
  module Lockstep
    class Error < StandardError; end
    class Timeout < Error; end
    class DriverNotSupportedError < StandardError; end
  end
end
