module Capybara
  module Lockstep
    module Logging
      def log(message)
        if debug? && message.present?
          message = "[Capybara::Lockstep] #{message}"
          if @debug.respond_to?(:debug)
            # If someone set Capybara::Lockstep to a logger, use that
            @debug.debug(message)
          else
            # Otherwise print to STDOUT
            puts message
          end
        end
      end
    end
  end
end