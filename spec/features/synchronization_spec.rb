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

    wait(0.5.seconds).for(command).to be_finished
  end

  it 'waits until a dynamically inserted image has loaded' do
    App.start_html = <<~HTML
      <a href="#" onclick="img = document.createElement('img'); img.src = '/next'; document.body.append(img)">label</a>
    HTML

    wall = Wall.new
    App.next_action = -> do
      wall.block
      content_type 'image/png'
      Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
    end

    visit '/start'
    command = ObservableCommand.new { page.find('a').click  }
    expect(command).to run_into_wall(wall)

    wall.release

    wait(0.5.seconds).for(command).to be_finished
  end

  it 'waits until a dynamically inserted image has failed to load' do
    App.start_html = <<~HTML
      <a href="#" onclick="img = document.createElement('img'); img.src = '/next'; document.body.append(img)">label</a>
    HTML

    wall = Wall.new
    App.next_action = -> do
      wall.block
      halt 404
    end

    visit '/start'
    command = ObservableCommand.new { page.find('a').click  }
    expect(command).to run_into_wall(wall)

    wall.release

    wait(0.5.seconds).for(command).to be_finished
  end

  it 'waits until a dynamically inserted script has loaded' do
    App.start_html = <<~HTML
      <a href="#" onclick="script = document.createElement('script'); script.src = '/next'; document.body.append(script)">label</a>
    HTML

    wall = Wall.new
    App.next_action = -> do
      wall.block
      content_type 'text/javascript'
      'document.body.style.backgroundColor = "blue"'
    end

    visit '/start'

    command = ObservableCommand.new { page.find('a').click  }
    expect(command).to run_into_wall(wall)

    wall.release

    wait(0.5.seconds).for(command).to be_finished
  end
end
