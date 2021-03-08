module Capybara
  module Lockstep
    module Helper

      JS_PATH = File.expand_path('../helper.js', __FILE__)
      JS = IO.read(JS_PATH)

      def capybara_lockstep_js
        JS
      end

      def capybara_lockstep(options = {})
        tag_options = {}

        # Add a CSRF nonce if supported by our Rails version
        if Rails.version >= '5'
          tag_options[:nonce] = options.fetch(:nonce, true)
        end

        js = capybara_lockstep_js + capybara_lockstep_config_js(options)
        javascript_tag(js, tag_options)
      end

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

if defined?(ActionView::Base)
  ActionView::Base.send :include, Capybara::Lockstep::Helper
end
