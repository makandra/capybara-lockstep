module Capybara
  module Lockstep
    module Logging
      def log(message)
        if Lockstep.debug? && message.present?
          message = "[capybara-lockstep] #{message}"
          if is_logger?(Lockstep.debug)
            # If someone set Capybara::Lockstep.debug to a logger, use that
            Lockstep.debug.debug(message)
          else
            # Otherwise print to STDOUT
            puts message
          end
        end
      end

      private

      def is_logger?(object)
        object.respond_to?(:debug)
      end
    end
  end
end
