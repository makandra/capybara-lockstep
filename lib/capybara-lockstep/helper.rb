module Capybara
  module Lockstep
    module Helper

      JAVASCRIPT_PATH = File.expand_path('../helper.js', __FILE__)
      JAVASCRIPT = IO.read(JAVASCRIPT_PATH)

      def capybara_lockstep(options = {})
        tag_options = {}

        # Add a CSRF nonce if supported by our Rails version
        if Rails.version >= '5'
          tag_options[:nonce] = options.fetch(:nonce, true)
        end

        javascript_tag(JAVASCRIPT, tag_options)
      end

    end
  end
end

if defined?(ActionView::Base)
  ActionView::Base.send :include, Capybara::Lockstep::Helper
end
