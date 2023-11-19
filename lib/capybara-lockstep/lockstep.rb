module Capybara
  module Lockstep

    class << self
      include Configuration
      include Logging

      attr_accessor :synchronizing
      alias synchronizing? synchronizing

      def synchronized_client?
        # The synchronized flag is per-session (page == Capybara.current_session).
        # This enables tests that use more than one browser, e.g. to test multi-user interaction:
        # https://makandracards.com/makandra/474480-how-to-make-a-cucumber-test-work-with-multiple-browser-sessions
        #
        # Ideally the synchronized flag would also be per-tab, per-frame and per-document.
        # We haven't found a way to patch this into Capybara, as there does not seem to be
        # a persistent object representing a document. Capybara::Node::Document just seems to
        # be a proxy accessing whatever is the current document. The way we work around this
        # is that we synchronize before switching tabs or frames.
        value = page.instance_variable_get(:@lockstep_synchronized_client)

        # We consider a new Capybara session to be synchronized.
        # This will be set to false after our first visit().
        value.nil? ? true : value
      end

      def unsynchronize_client
        self.synchronized_client = false
      end

      alias :unsynchronize :unsynchronize_client

      def synchronized_client=(value)
        page.instance_variable_set(:@lockstep_synchronized_client, value)
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
        # The { lazy } option has nothing todo with :auto mode.
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
        will_synchronize_client = !(lazy && synchronized_client?)

        begin
          # Synchronizing the server is free, so we ignore { lazy } and do it every time.
          server.synchronize

          if will_synchronize_client
            self.log(log)
            self.synchronizing = true
            unsynchronize_client
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

      delegate :start_work, :end_work, to: :server

      private

      def page
        Capybara.current_session
      end

      def server
        @server ||= Server.new
      end

      def client
        @client ||= Client.new
      end

    end
  end
end

