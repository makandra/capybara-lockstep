class Wall

  def initialize
    reset
  end

  def block
    @queue.pop
  end

  def release
    @queue.push(:value)
  end

  delegate :num_waiting, to: :@queue

  def blocking?
    num_waiting > 0
  end

  def reset
    @queue = Queue.new
  end

end
