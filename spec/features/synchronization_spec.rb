describe 'synchronization' do

  describe 'on click' do

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

    it 'does not close an alert that was opened on click' do
      App.start_html = <<~HTML
        <a href="#" onclick="confirm('OK to proceed?')">label</a>
      HTML

      visit '/start'
      page.find('a').click
      page.accept_confirm('OK to proceed?')
    end

    it 'does not crash if the click closes the window' do
      App.start_html = <<~HTML
        <a href="/start" target="_blank"">open window</a>
        <a href="#" onclick="window.close()"">close window</a>
      HTML

      visit '/start'

      window = window_opened_by do
        find('a', text: 'open window').click
      end

      expect do
        within_window(window) do
          find('a', text: 'close window').click
        end
      end.to_not raise_error

    end

  end

  describe 'when reading elements' do

    it "synchronizes before accessing an element, without relying on Capybara's reload mechanic" do
      App.start_html = <<~HTML
        <div id="content">old content</div>
      HTML

      App.start_script = <<~JS
        CapybaraLockstep.startWork('spec')
        setTimeout(() => {
          CapybaraLockstep.stopWork('spec')
          document.querySelector('#content').textContent = 'new content'
        }, 500)
      JS

      visit '/start'

      page.using_wait_time(0) do
        expect(page).to have_css('#content', text: 'new content')
      end
    end

  end

  describe 'script execution' do

    it 'synchronizes before evaluate_script' do
      App.start_html = <<~HTML
        <div id="content">old content</div>
      HTML

      App.start_script = <<~JS
        CapybaraLockstep.startWork('spec')
        window.myProp = 'value before work'

        setTimeout(() => {
          CapybaraLockstep.stopWork('spec')
          window.myProp = 'value after work'
        }, 500)
      JS

      visit '/start'

      page.using_wait_time(0) do
        expect(page.evaluate_script('myProp')).to eq('value after work')
      end
    end

  end

end
