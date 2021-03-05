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

        full_js = capybara_lockstep_js

        if (debug = options.fetch(:debug, Lockstep.debug?))
          full_js += "\nCapybaraLockstep.debug = #{debug.to_json}"
        end

        javascript_tag(full_js, tag_options)
      end

    end
  end
end

if defined?(ActionView::Base)
  ActionView::Base.send :include, Capybara::Lockstep::Helper
end
