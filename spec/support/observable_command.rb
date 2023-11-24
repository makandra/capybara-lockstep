class ObservableCommand

  def initialize(&block)
    @state = :initialized
    @block = block
    @error = nil
  end

  attr_reader :state, :error

  # Don't name it #call or expect() and wait() will automatically call it
  def execute
    @state = :running
    Thread.new do
      @block.call
      @state = :finished
    rescue Exception => error
      @error = error
      @state = :failed
    end
  end

  def initialized?
    state == :initialized
  end

  def running?
    state == :running
  end

  def finished?
    state == :finished
  end

  def failed?
    state == :failed?
  end

end
