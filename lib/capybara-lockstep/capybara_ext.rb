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
        visiting_remote_url = !(url.start_with?('data:') || url.start_with?('about:'))

        if visiting_remote_url
          # We're about to leave this screen, killing all in-flight requests.
          Capybara::Lockstep.synchronize
        end

        super(*args, &block).tap do
          if visiting_remote_url
            # puts "After visit: unsynchronizing"
            Capybara::Lockstep.synchronized = false
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
    module UnsychronizeAfter
      def unsychronize_after(meth)
        mod = Module.new do
          define_method meth do |*args, &block|
            super(*args, &block).tap do
              Capybara::Lockstep.synchronized = false
            end
          end
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
      def synchronize(*args, &block)
        # This method is called very frequently by capybara.
        # We use the { lazy } option to only synchronize when we're out of sync.
        Capybara::Lockstep.synchronize(lazy: true)

        super(*args, &block)
      end
    end
  end
end

Capybara::Node::Base.class_eval do
  prepend Capybara::Lockstep::SynchronizeWithCatchUp
end
