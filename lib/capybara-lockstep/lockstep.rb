module Capybara
  module Lockstep
    class << self
      include Configuration
      include Logging
      include PageAccess

      attr_accessor :synchronizing
      alias synchronizing? synchronizing

      def unsynchronize
        return if mode == :off

        client.synchronized = false
      end

      # Automatic synchronization from within the capybara-lockstep should always call #auto_synchronize.
      # This only synchronizes IFF in :auto mode, i.e. the user has not explicitly disabled automatic syncing.
      # The :auto mode has nothing to do with the { lazy } option.
      def auto_synchronize(**options)
        if mode == :auto
          synchronize(**options)
        end
      end

      def synchronize(lazy: false, log: 'Synchronizing')
        if synchronizing? || mode == :off
          return
        end

        # The { lazy } option is a performance optimization that will prevent capybara-lockstep
        # from synchronizing multiple times in expressions like `page.find('.foo').find('.bar')`.
        # The { lazy } option has nothing to do with :auto mode.
        #
        # With { lazy: true } we only synchronize when the Ruby-side thinks we're out of sync.
        # This saves us an expensive execute_script() roundtrip that goes to the browser and back.
        # However the knowledge of the Ruby-side is limited: We only assume that we're out of sync
        # after a page load or after a Capybara command. There may be additional client-side work
        # that the Ruby-side is not aware of, e.g. an AJAX call scheduled by a timeout.
        #
        # With { lazy: false } we force synchronization with the browser, whether the Ruby-side
        # thinks we're in sync or not. This always makes an execute_script() rountrip, but picks up
        # non-lazy synchronization so we pick up client-side work that have not been caused
        # by Capybara commands.
        will_synchronize_client = !(lazy && client.synchronized?)

        begin
          # Synchronizing the server is free, so we ignore { lazy } and do it every time.
          server.synchronize

          if will_synchronize_client
            self.log(log)
            self.synchronizing = true
            client.synchronize
            # Synchronizing the server is free, so we ignore { lazy } and do it every time.
            server.synchronize
          end
        ensure
          self.synchronizing = false
        end

        if will_synchronize_client
          run_after_synchronize_callbacks
        end
      end

      delegate :start_work, :stop_work, to: :server

      def server
        @server ||= Server.new
      end

      def client
        if @client.nil? || !@client.is_a?(client_class)
          # (Re-)Initialize client if missing or the current driver changes
          @client = client_class.new
        end

        @client
      end

      def client_class
        if selenium_driver?
          Client::Selenium
        elsif cuprite_driver?
          Client::Cuprite
        else
          # This should never raise, as capybara lockstep should disable itself for any unsupported driver.
          # When it still does, there is probably a bug within capybara lockstep.
          raise DriverNotSupportedError, "The driver #{driver.class.name} is not supported by capybara-lockstep."
        end
      end

    end
  end
end
