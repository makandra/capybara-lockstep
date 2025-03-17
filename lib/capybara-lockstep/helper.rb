module Capybara
  module Lockstep
    module Helper

      JS_PATH = File.expand_path('../helper.js', __FILE__)
      HELPER_JS = IO.read(JS_PATH)

      def capybara_lockstep_js(options = {})
        HELPER_JS + capybara_lockstep_config_js(options)
      end

      def capybara_lockstep(options = {})
        tag_options = {}

        # Add a CSRF nonce if supported by our Rails version
        if Rails.version >= '5'
          tag_options[:nonce] = options.fetch(:nonce, true)
        end

        javascript_tag(capybara_lockstep_js(options), tag_options)
      end

      private

      def capybara_lockstep_config_js(options = {})
        js = ''

        if (debug = options.fetch(:debug, Lockstep.debug?))
          js += "\nCapybaraLockstep.debug = #{debug.to_json}"
        end

        if (wait_tasks = options.fetch(:wait_tasks, Lockstep.wait_tasks))
          js += "\nCapybaraLockstep.waitTasks = #{wait_tasks.to_json}"
        end

        js
      end

    end
  end
end

ActiveSupport.on_load(:action_view) do
  ActionView::Base.send(:include, Capybara::Lockstep::Helper)
end
