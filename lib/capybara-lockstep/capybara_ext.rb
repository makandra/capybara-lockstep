require 'ruby2_keywords'

module Capybara
  module Lockstep
    module SynchronizeMacros

      def synchronize_before(meth, lazy:)
        mod = Module.new do
          define_method meth do |*args, &block|
            Lockstep.auto_synchronize(lazy: lazy, log: "Synchronizing before ##{meth}")
            super(*args, &block)
          end

          ruby2_keywords meth
        end

        prepend(mod)
      end

      def synchronize_after(meth)
        mod = Module.new do
          define_method meth do |*args, &block|
            super(*args, &block)
          ensure
            Lockstep.auto_synchronize
          end

          ruby2_keywords meth
        end

        prepend(mod)
      end

      def unsynchronize_after(meth)
        mod = Module.new do
          define_method meth do |*args, &block|
            super(*args, &block)
          ensure
            Lockstep.unsynchronize
          end

          ruby2_keywords meth
        end

        prepend(mod)
      end

    end
  end
end

Capybara::Session.class_eval do
  extend Capybara::Lockstep::SynchronizeMacros

  synchronize_before :html, lazy: true # wait until running JavaScript has updated the DOM

  synchronize_before :current_url, lazy: true # wait until running JavaScript has updated the URL

  synchronize_before :refresh, lazy: false # wait until running JavaScript has updated the URL
  unsynchronize_after :refresh # new document is no longer synchronized

  synchronize_before :go_back, lazy: false # wait until running JavaScript has updated the URL
  unsynchronize_after :go_back # new document is no longer synchronized

  synchronize_before :go_forward, lazy: false # wait until running JavaScript has updated the URL
  unsynchronize_after :go_forward # new document is no longer synchronized

  synchronize_before :switch_to_frame, lazy: true # wait until the current frame is done processing
  unsynchronize_after :switch_to_frame # now that we've switched into the new frame, we don't know the document's synchronization state.

  synchronize_before :switch_to_window, lazy: true # wait until the current frame is done processing
  unsynchronize_after :switch_to_window # now that we've switched to the new window, we don't know the document's synchronization state.
end

module Capybara
  module Lockstep
    module VisitWithWaiting
      def visit(*args, &block)
        url = args[0]
        # Some of our apps have a Cucumber step that changes drivers mid-scenario.
        # It works by creating a new Capybara session and re-visits the URL from the
        # previous session. If this happens before a URL is ever loaded,
        # it re-visits the URL "data:", which will never "finish" initializing.
        # Also when opening a new tab via Capybara, the initial URL is about:blank.
        visiting_real_url = !(url.start_with?('data:') || url.start_with?('about:'))

        if visiting_real_url
          # We're about to leave this screen, killing all in-flight requests.
          # Give pending form submissions etc. a chance to finish before we tear down
          # the browser environment.
          #
          # We force a non-lazy synchronization so we pick up all client-side changes
          # that have not been caused by Capybara commands.
          Lockstep.auto_synchronize(lazy: false, log: "Synchronizing before visiting #{url}")
        end

        super(*args, &block).tap do
          if visiting_real_url
            # We haven't yet synchronized the new screen.
            Lockstep.unsynchronize
          end
        end
      end

      ruby2_keywords :visit
    end
  end
end

Capybara::Session.class_eval do
  prepend Capybara::Lockstep::VisitWithWaiting
end

module Capybara
  module Lockstep
    module SynchronizeAroundScriptMethod

      def synchronize_around_script_method(meth)
        mod = Module.new do
          define_method meth do |script, *args, &block|
            # Synchronization uses execute_script itself, so don't synchronize when
            # we're already synchronizing.
            if !Lockstep.synchronizing?
              # It's generally a good idea to synchronize before a JavaScript wants
              # to access or observe an earlier state change.
              #
              # In case the given script navigates away (with `location.href = url`,
              # `history.back()`, etc.) we would kill all in-flight requests. For this case
              # we force a non-lazy synchronization so we pick up all client-side changes
              # that have not been caused by Capybara commands.
              script_may_navigate_away = script =~ /\b(location|history)\b/
              Lockstep.auto_synchronize(lazy: !script_may_navigate_away, log: "Synchronizing before script: #{script}")
            end

            super(script, *args, &block)
          ensure
            if !Lockstep.synchronizing?
              # We haven't yet synchronized with whatever changes the JavaScript
              # did on the frontend.
              Lockstep.unsynchronize
            end
          end

          ruby2_keywords meth
        end
        prepend(mod)
      end

    end
  end
end

Capybara::Session.class_eval do
  extend Capybara::Lockstep::SynchronizeAroundScriptMethod

  synchronize_around_script_method :execute_script
  synchronize_around_script_method :evaluate_script
  synchronize_around_script_method :evaluate_async_script
end

# Capybara 3 has driver-specific Node classes which sometimes
# super to Capybara::Selenium::Node, but not always.
node_classes = [
  (Capybara::Selenium::ChromeNode  if defined?(Capybara::Selenium::ChromeNode)),
  (Capybara::Selenium::FirefoxNode if defined?(Capybara::Selenium::FirefoxNode)),
  (Capybara::Selenium::SafariNode  if defined?(Capybara::Selenium::SafariNode)),
  (Capybara::Selenium::EdgeNode    if defined?(Capybara::Selenium::EdgeNode)),
  (Capybara::Selenium::IENode      if defined?(Capybara::Selenium::IENode)),
  (Capybara::Playwright::Node      if defined?(Capybara::Playwright::Node)),
].compact

if node_classes.empty?
  # Capybara 2 has no driver-specific Node implementations,
  # so we patch the shared base class.
  node_classes = [Capybara::Selenium::Node]
end

node_classes.each do |node_class|
  node_class.class_eval do
    extend Capybara::Lockstep::SynchronizeMacros

    synchronize_before :set, lazy: true
    unsynchronize_after :set
    synchronize_after :set

    synchronize_before :select_option, lazy: true
    unsynchronize_after :select_option
    synchronize_after :select_option

    synchronize_before :unselect_option, lazy: true
    unsynchronize_after :unselect_option
    synchronize_after :unselect_option

    synchronize_before :click, lazy: true
    unsynchronize_after :click
    synchronize_after :click

    synchronize_before :right_click, lazy: true
    unsynchronize_after :right_click
    synchronize_after :right_click

    synchronize_before :double_click, lazy: true
    unsynchronize_after :double_click
    synchronize_after :double_click

    synchronize_before :send_keys, lazy: true
    unsynchronize_after :send_keys
    synchronize_after :send_keys

    synchronize_before :hover, lazy: true
    unsynchronize_after :hover
    synchronize_after :hover

    synchronize_before :drag_to, lazy: true
    unsynchronize_after :drag_to
    synchronize_after :drag_to

    synchronize_before :drop, lazy: true
    unsynchronize_after :drop
    synchronize_after :drop

    synchronize_before :scroll_by, lazy: true
    unsynchronize_after :scroll_by
    synchronize_after :scroll_by

    synchronize_before :scroll_to, lazy: true
    unsynchronize_after :scroll_to
    synchronize_after :scroll_to

    synchronize_before :trigger, lazy: true
    unsynchronize_after :trigger
    synchronize_after :trigger
  end
end

module Capybara
  module Lockstep
    module SynchronizeWithCatchUp
      def synchronize(*args, &block)
        # This method is called by Capybara before most interactions with
        # the browser. It is a different method than Capybara::Lockstep.synchronize!
        # We use the { lazy } option to only synchronize when we're out of sync.
        Lockstep.auto_synchronize(lazy: true, log: 'Synchronizing before node access')

        super(*args, &block)
      end

      ruby2_keywords :synchronize
    end
  end
end

Capybara::Node::Base.class_eval do
  prepend Capybara::Lockstep::SynchronizeWithCatchUp
end
