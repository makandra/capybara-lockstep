describe 'synchronization' do

  it 'renders the app' do
    visit '/start'
    expect(page).to have_content('hi world')
  end

  it 'waits until an AJAX request has finished' do
    App.start_html = <<~HTML
      <a href="#" onclick="fetch('/next')">label</a>
    HTML

    wall = Wall.new
    App.next_action = -> { wall.block }

    visit '/start'
    command = ObservableCommand.new { page.find('a').click  }
    expect(command).to run_into_wall(wall)

    wall.release

    wait(0.1.seconds).for(command).to be_finished
  end

end
