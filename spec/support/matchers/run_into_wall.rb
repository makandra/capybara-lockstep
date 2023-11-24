RSpec::Matchers.define :run_into_wall do |wall|
  include RSpec::Wait

  match(notify_expectation_failures: true) do |command|
    expect(command).to be_initialized
    expect(wall).to_not be_blocking

    command.execute

    expect(command).to be_running
    wait(0.5.seconds).for(wall).to be_blocking

    sleep(0.25.seconds)
    expect(command).to be_running
    expect(wall).to be_blocking
  end

end
