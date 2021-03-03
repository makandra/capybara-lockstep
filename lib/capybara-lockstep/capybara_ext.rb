module Capybara
  module Lockstep
    module VisitWithWaiting
      def visit(*args, &block)
        visiting_remote_url = !args[0].start_with?('data:')

        Capybara::Lockstep.catch_up

        super(*args, &block).tap do
          # There is a step that changes drivers mid-scenario.
          # It works by creating a new Capybara session and re-visits the
          # URL from the previous session. If this happens before a URL is ever
          # loaded, it re-visits the URL "data:", which will never "finish"
          # initializing.
          if visiting_remote_url
            Capybara::Lockstep.await_initialized
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
    module AwaitIdle
      def await_idle(meth)
        mod = Module.new do
          define_method meth do |*args, &block|
            Capybara::Lockstep.catch_up
            super(*args, &block).tap do
              Capybara::Lockstep.await_idle
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
    extend Capybara::Lockstep::AwaitIdle

    await_idle :set
    await_idle :select_option
    await_idle :unselect_option
    await_idle :click
    await_idle :right_click
    await_idle :double_click
    await_idle :send_keys
    await_idle :hover
    await_idle :drag_to
    await_idle :drop
    await_idle :scroll_by
    await_idle :scroll_to
    await_idle :trigger
  end
end

module Capybara
  module Lockstep
    module SynchronizeWithCatchUp
      def synchronize(*args, &block)
        Capybara::Lockstep.catch_up

        super(*args, &block)
      end
    end
  end
end

Capybara::Node::Base.class_eval do
  prepend Capybara::Lockstep::SynchronizeWithCatchUp
end
