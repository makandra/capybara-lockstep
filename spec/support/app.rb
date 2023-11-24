require 'sinatra'
require 'active_support/core_ext/class/attribute'

class App < Sinatra::Base
  include Capybara::Lockstep::Helper

  class_attribute :start_html, :start_script, :next_action
  delegate :start_html, :start_script, :next_action, :reset, to: :class

  get '/start' do
    render_body(<<~HTML)
      #{start_html}
      <script>#{start_script}</script>
    HTML
  end

  get '/next' do
    next_action.call
  end

  def self.reset
    self.start_html = 'hi world'
    self.start_script = 'console.log("loaded")'
    self.next_action = -> { 'hello from /next' }
  end

  private

  def render_body(content)
    <<~HTML
      <html>
        <head>
          <script>#{capybara_lockstep_js}</script>
        </head>
        <body>
          #{content}
        </body>
      </html>
    HTML
  end

end
