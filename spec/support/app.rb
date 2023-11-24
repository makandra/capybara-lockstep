require 'sinatra'
require 'active_support/core_ext/class/attribute'

class InspectableLock

  def initialize
    reset
  end

  def lock
    @queue.pop
  end

  def unlock
    @queue.push(:value)
  end

  delegate :num_waiting, to: :@queue

  def waiting?
    num_waiting > 0
  end

  def reset
    @queue = Queue.new
  end

end


class App < Sinatra::Base

  class_attribute :start_html, :start_script, :lock
  delegate :start_html, :start_script, :lock, :reset, to: :class

  get '/start' do
    render_body(<<~HTML)
      #{start_html}
      <script>#{start_script}</script>
    HTML
  end

  get '/locked' do
    lock.lock
  end

  def self.reset
    self.start_html = 'hi world'
    self.start_script = 'console.log("loaded")'
    self.lock = InspectableLock.new
  end

  private

  def render_body(content)
    <<~HTML
      <html>
        <body>
          #{content}
        </body>
      </html>
    HTML
  end

end
