module Capybara
  module Lockstep
    module Util
      class << self
        def with_max_wait_time(seconds, &block)
          old_max_wait_time = Capybara.default_max_wait_time
          Capybara.default_max_wait_time = seconds
          begin
            block.call
          ensure
            Capybara.default_max_wait_time = old_max_wait_time
          end
        end

        def current_seconds
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
