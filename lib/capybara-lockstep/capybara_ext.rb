require 'ruby2_keywords'

module Capybara
  module Lockstep
    module VisitWithWaiting
      ruby2_keywords def visit(*args, &block)
        url = args[0]
        # Some of our apps have a Cucumber step that changes drivers mid-scenario.
        # It works by creating a new Capybara session and re-visits the URL from the
        # previous session. If this happens before a URL is ever loaded,
        # it re-visits the URL "data:", which will never "finish" initializing.
        # Also when opening a new tab via Capybara, the initial URL is about:blank.
        visiting_remote_url = !(url.start_with?('data:') || url.start_with?('about:'))

        if visiting_remote_url
          # We're about to leave this screen, killing all in-flight requests.
          # Give pending form submissions etc. a chance to finish before we tear down
          # the browser environment.
          #
          # We force a non-lazy synchronization so we pick up all client-side changes
          # that have not been caused by Capybara commands.
          Lockstep.synchronize(lazy: false)
        end

        super(*args, &block).tap do
          if visiting_remote_url
            # We haven't yet synchronized the new screen.
            Lockstep.synchronized = false
          end
        end
      end
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

            super(script, *args, &block).tap do
              if !Lockstep.synchronizing?
                # We haven't yet synchronized with whatever changes the JavaScript
                # did on the frontend.
                Lockstep.synchronized = false
              end
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
  synchronize_around_script_method :evaluate_async_script
  # Don't synchronize around evaluate_script. It calls execute_script
  # internally and we don't want to synchronize multiple times.
end

module Capybara
  module Lockstep
    module UnsychronizeAfter
      def unsychronize_after(meth)
        mod = Module.new do
          define_method meth do |*args, &block|
            super(*args, &block).tap do
              Lockstep.synchronized = false
            end
          end
          ruby2_keywords meth
        end
        prepend(mod)
      end
    end
  end
end

# Capybara 3 has driver-specific Node classes which sometimes
# super to Capybara::Selenium::Node, but not always.
node_classes = [
  (Capybara::Selenium::ChromeNode  if defined?(Capybara::Selenium::ChromeNode)),
  (Capybara::Selenium::FirefoxNode if defined?(Capybara::Selenium::FirefoxNode)),
  (Capybara::Selenium::SafariNode  if defined?(Capybara::Selenium::SafariNode)),
  (Capybara::Selenium::EdgeNode    if defined?(Capybara::Selenium::EdgeNode)),
  (Capybara::Selenium::IENode      if defined?(Capybara::Selenium::IENode)),
].compact

if node_classes.empty?
  # Capybara 2 has no driver-specific Node implementations,
  # so we patch the shared base class.
  node_classes = [Capybara::Selenium::Node]
end

node_classes.each do |node_class|
  node_class.class_eval do
    extend Capybara::Lockstep::UnsychronizeAfter

    unsychronize_after :set
    unsychronize_after :select_option
    unsychronize_after :unselect_option
    unsychronize_after :click
    unsychronize_after :right_click
    unsychronize_after :double_click
    unsychronize_after :send_keys
    unsychronize_after :hover
    unsychronize_after :drag_to
    unsychronize_after :drop
    unsychronize_after :scroll_by
    unsychronize_after :scroll_to
    unsychronize_after :trigger
  end
end

module Capybara
  module Lockstep
    module SynchronizeWithCatchUp
      ruby2_keywords def synchronize(*args, &block)
        # This method is called by Capybara before most interactions with
        # the browser. It is a different method than Capybara::Lockstep.synchronize!
        # We use the { lazy } option to only synchronize when we're out of sync.
        Capybara::Lockstep.auto_synchronize(lazy: true)

        super(*args, &block)
      end
    end
  end
end

Capybara::Node::Base.class_eval do
  prepend Capybara::Lockstep::SynchronizeWithCatchUp
end
