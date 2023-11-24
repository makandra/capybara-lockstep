class ObservableLock

  def initialize
    reset
  end

  def wait
    @queue.pop
  end

  def release
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
