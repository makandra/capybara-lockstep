module Capybara
  module Lockstep
    class Error < StandardError; end
    class Busy < Error; end
  end
end
