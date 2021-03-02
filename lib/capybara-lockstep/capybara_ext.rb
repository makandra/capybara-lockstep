module Capybara
  module Lockstep
    module VisitWithWaiting
      def visit(*args, **kwargs, &block)
        super(*args, **kwargs, &block).tap do
          # There is a step that changes drivers mid-scenario.
          # It works by creating a new Capybara session and re-visits the
          # URL from the previous session. If this happens before a URL is ever
          # loaded, it re-visits the URL "data:", which will never "finish"
          # initializing.
          unless args[0].start_with?('data:')
            Capybara::Lockstep.await_initialized
          end
        end
      end
    end

    module AwaitIdle
      def await_idle(meth)
        mod = Module.new do
          define_method meth do |*args, **kwargs, &block|
            super(*args, **kwargs, &block).tap do
              Capybara::Lockstep.await_idle
            end
          end
        end
        prepend(mod)
      end
    end
  end
end

Capybara::Session.class_eval do
  prepend Capybara::Lockstep::VisitWithWaiting
end

if defined?(Capybara::Selenium::ChromeNode)
  # Capybara 3
  node_class = Capybara::Selenium::ChromeNode
else
  # Capybara 2
  node_class = Capybara::Selenium::Node
end

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
