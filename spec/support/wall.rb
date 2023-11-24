class Wall

  def initialize
    @queue = Queue.new
    @mutex = Mutex.new
  end

  def block
    self.class.blocking_walls.push(self)
    @queue.pop # this will block until #release pushses a value
  end

  def release
    self.class.blocking_walls.delete(self)
    @queue.push(:value)
  end

  delegate :num_waiting, to: :@queue

  def blocking?
    num_waiting > 0
  end

  def self.blocking_walls
    @blocking_walls ||= []
  end

end

RSpec.configure do |config|
  config.after(:each) do
    Wall.blocking_walls.dup.each(&:release)
  end
end
