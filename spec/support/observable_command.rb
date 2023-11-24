class ObservableCommand

  def initialize(&block)
    @state = :initialized
    @block = block
  end

  attr_reader :state

  # Don't name it #call or expect() and wait() will automatically call it
  def execute
    @state = :running
    $stdout.puts "[ObservableCommand] State is now #{state.inspect}"
    Thread.new do
      @block.call
      @state = :finished
      $stdout.puts "[ObservableCommand] State is now #{state.inspect}"
    rescue Exception
      @state = :failed
      $stdout.puts "[ObservableCommand] State is now #{state.inspect}"
    end
  end

  def has_state?(state)
    $stdout.puts "has_state?(#{state.inspect}) => #{(self.state == state).inspect} because @state is #{self.state.inspect}"
    self.state == state
  end

end
