describe 'synchronization' do

  it 'renders the app' do
    visit '/start'
    expect(page).to have_content('hi world')
  end

  it 'waits until an AJAX request has finished' do
    App.start_html = <<~HTML
      <a href="#" onclick="fetch('/lock')">label</a>
    HTML

    visit '/start'

    command = ObservableCommand.new do
      $stdout.puts "block: Starting command"
      page.find('a').click
      $stdout.puts "block: Command done"
    end

    $stdout.puts "Locking app"

    $stdout.puts "Calling command"

    command.execute

    $stdout.puts "Waiting for lock to be waiting"

    expect(command).to have_state(:running)
    wait(1.second).for(App.lock).to be_waiting

    sleep(0.5.seconds)
    expect(command).to have_state(:running)

    $stdout.puts "UNLOCKING"
    App.lock.release

    wait(0.1.seconds).for(command).to have_state(:finished)
  end

end
