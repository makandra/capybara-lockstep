require 'sinatra'
require 'active_support/core_ext/class/attribute'

class App < Sinatra::Base
  include Capybara::Lockstep::Helper

  class_attribute :start_html, :start_script, :lock
  delegate :start_html, :start_script, :lock, :reset, to: :class

  get '/start' do
    Kernel.puts '[app] /start'
    render_body(<<~HTML)
      #{start_html}
      <script>#{start_script}</script>
    HTML
  end

  get '/lock' do
    Kernel.puts '[app] /lock start'
    lock.wait
    Kernel.puts '[app] /lock end'
    'ok'
  end

  def self.reset
    self.start_html = 'hi world'
    self.start_script = 'console.log("loaded")'
    self.lock = ObservableLock.new
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
