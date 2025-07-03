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

      wait(0.5.seconds).for { command }.to be_finished
    end

    describe 'dynamically inserted images' do

      it 'waits until the has loaded' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let img = document.createElement('img');
            img.src = '/next';
            document.body.append(img);
          ">label</a>
        HTML

        wall = Wall.new
        App.next_action = -> do
          wall.block
          send_file_sync('spec/fixtures/image.png', 'image/png')
        end

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        expect(command).to run_into_wall(wall)

        wall.release

        wait(0.5.seconds).for { command }.to be_finished

        expect('img').to be_loaded_image
      end

      it 'waits until the has failed to load' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let img = document.createElement('img');
            img.src = '/next';
            document.body.append(img);
          ">label</a>
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

        wait(0.5.seconds).for { command }.to be_finished

        expect('img').to be_broken_image
      end

      it 'does not wait forever for an image with a data: source' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let img = document.createElement('img');
            img.src = `data:image/png;base64,#{Base64.encode64(File.read('spec/fixtures/image.png')).gsub("\n", '')}`;
            document.body.append(img);
          ">label</a>
        HTML

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        command.execute

        wait(0.2.seconds).for { command }.to be_finished

        expect('img').to be_loaded_image
      end

      it 'does not wait for an image with [loading=lazy]' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let img = document.createElement('img');
            img.setAttribute('loading', 'lazy');
            img.src =' /next';
            document.body.append(img);
          ">label</a>

          #{(1...500).map { |i| "<p>#{i}</p>" }.join}
        HTML

        server_spy = double('server action', reached: nil)

        App.next_action = -> do
          server_spy.reached
        end

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        command.execute

        wait(0.2.seconds).for { command }.to be_finished

        expect(server_spy).to_not have_received(:reached)
      end

    end

    describe 'dynamically inserted iframes' do

      it 'waits until the iframe has loaded' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let iframe = document.createElement('iframe');
            iframe.src = '/next';
            document.body.append(iframe);
          ">label</a>
        HTML

        wall = Wall.new
        App.next_action = -> do
          wall.block
          render_body('hello from iframe')
        end

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        expect(command).to run_into_wall(wall)

        wall.release

        wait(0.5.seconds).for { command }.to be_finished
      end

      it 'waits until the iframe has failed to load' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let iframe = document.createElement('iframe');
            iframe.src = '/next';
            document.body.append(iframe);
          ">label</a>
        HTML

        wall = Wall.new
        App.next_action = -> do
          wall.block
          halt 500
        end

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        expect(command).to run_into_wall(wall)

        wall.release

        wait(0.5.seconds).for { command }.to be_finished
      end

      it 'does not wait forever for an iframe with a data: source' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let iframe = document.createElement('iframe');
            iframe.src = `data:text/html;base64,#{Base64.encode64('hello from iframe').gsub("\n", '')}`;
            document.body.append(iframe);
          ">label</a>
        HTML

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        command.execute

        wait(0.2.seconds).for { command }.to be_finished
      end

      it 'does not wait for an iframe with [loading=lazy]' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let iframe = document.createElement('iframe');
            iframe.setAttribute('loading', 'lazy');
            iframe.src =' /next';
            document.body.append(iframe);
          ">label</a>

          #{(1...500).map { |i| "<p>#{i}</p>" }.join}
        HTML

        server_spy = double('server action', reached: nil)

        App.next_action = -> do
          server_spy.reached
        end

        visit '/start'
        command = ObservableCommand.new { page.find('a').click  }
        command.execute

        wait(0.2.seconds).for { command }.to be_finished

        expect(server_spy).to_not have_received(:reached)
      end

    end

    describe 'dynamically loaded scripts' do

      it 'waits until a <script> has loaded' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let script = document.createElement('script');
            script.src = '/next';
            document.body.append(script);
          ">label</a>
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

        wait(0.5.seconds).for { command }.to be_finished
      end

      it 'waits until a <script type="module"> has loaded' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let script = document.createElement('script');
            script.type = 'module';
            script.src = '/next';
            document.body.append(script);
          ">label</a>
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

        wait(0.5.seconds).for { command }.to be_finished
      end

      it 'does not wait for a <script> with a non-JavaScript [type]' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let script = document.createElement('script');
            script.type = 'text/dreamberd';
            script.src = '/next';
            document.body.append(script);
          ">label</a>
        HTML

        wall = Wall.new
        App.next_action = -> do
          wall.block
          content_type 'text/dreamberd'
          'const const scores = [3, 2, 5]'
        end

        visit '/start'

        command = ObservableCommand.new { page.find('a').click  }
        command.execute
        wait(0.5.seconds).for { command }.to be_finished
      end

      it 'does not wait forever for an inline script' do
        App.start_html = <<~HTML
          <a href="#" onclick="
            let script = document.createElement('script');
            script.innerText = 'window.EFFECT = 123';
            document.body.append(script);
          ">label</a>
        HTML

        wall = Wall.new
        App.next_action = -> do
          wall.block
          content_type 'text/javascript'
          'document.body.style.backgroundColor = "blue"'
        end

        visit '/start'

        command = ObservableCommand.new { page.find('a').click  }
        command.execute
        wait(0.2.seconds).for { command }.to be_finished

        expect(evaluate_script('EFFECT')).to eq(123)
      end

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

    it 'stays busy for the configured number of tasks' do
      Capybara::Lockstep.mode = :off
      Capybara::Lockstep.wait_tasks = 10

      App.start_html = <<~HTML
        <a href="#">label</a>
      HTML

      visit '/start'
      page.find('a').click

      expect(page.evaluate_script('CapybaraLockstep.isBusy()')).to eq(true)

      sleep (0.004 * 10)

      expect(page.evaluate_script('CapybaraLockstep.isBusy()')).to eq(false)
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

  describe 'history navigation' do

    it 'stays busy for a bit after history.pushState()' do
      visit '/start'

      Capybara::Lockstep.mode = :manual

      busy = page.evaluate_script(<<~JS)
        (function() {
          history.pushState({}, '', '/next')
          return CapybaraLockstep.isBusy()
        })()
      JS

      expect(busy).to be(true)

      Capybara::Lockstep.synchronize

      busy = page.evaluate_script(<<~JS)
        CapybaraLockstep.isBusy()
      JS

      expect(busy).to be(false)
    end

    it 'stays busy for a bit when navigating through history' do
      visit '/start'

      Capybara::Lockstep.mode = :manual

      page.evaluate_async_script(<<~JS)
        let [done] = arguments
        history.pushState({}, '', '/next')
        setTimeout(done, 50)
      JS

      busy = page.evaluate_script(<<~JS)
        (function() {
          history.back()
          return CapybaraLockstep.isBusy()
        })()
      JS

      expect(busy).to be(true)

      busy = page.evaluate_script(<<~JS)
        CapybaraLockstep.isBusy()
      JS

      expect(busy).to be(false)
    end

  end

  describe 'navigating with #visit' do

    it 'does not crash and visits the root route when called with nil' do
      visit(nil)

      expect(page).to have_content('Root page')
    end

  end

  describe 'settimeout' do
    it 'waits for the timeout to complete' do
      Capybara::Lockstep.wait_timeout_max_delay = 1000

      App.start_script = <<~JS
        setTimeout(() => {
          document.querySelector('body').textContent = 'adjusted page'
        }, 999)
      JS

      visit '/start'

      expect(page).to have_content('adjusted page')
    end

    it 'waits is there is no timeout specified' do
      App.start_script = <<~JS
        setTimeout(() => {
          document.querySelector('body').textContent = 'adjusted page'
        })
      JS

      visit '/start'

      expect(page).to have_content('adjusted page')
    end

    it 'does not wait for the timeout to complete if it takes > configured wait timeout' do
      Capybara::Lockstep.wait_timeout_max_delay = 1000

      App.start_script = <<~JS
        setTimeout(() => {
          document.querySelector('body').textContent = 'adjusted page'
        }, 1001)
      JS

      visit '/start'

      expect(page).not_to have_content('adjusted page')
    end

    it 'does not wait for the timeout to complete if the callback is an async function' do
      Capybara::Lockstep.wait_timeout_max_delay = 1000

      App.start_script = <<~JS
        setTimeout(async () => {
          document.querySelector('body').textContent = 'adjusted page'
        }, 1000)
      JS
      visit '/start'

      expect(page).not_to have_content('adjusted page')
    end

    it 'stops waiting if clearTimeout is called' do
      Capybara::Lockstep.wait_timeout_max_delay = 1000

      App.start_script = <<~JS
        let timeoutId = setTimeout(() => {
          document.querySelector('body').textContent = 'adjusted page'
        }, 500)
        clearTimeout(timeoutId)
      JS

      visit '/start'

      expect(page).not_to have_content('adjusted page')
    end

    it 'keeps waiting for the configured wait timeout max delay' do
      Capybara::Lockstep.wait_timeout_max_delay = 3000

      App.start_script = <<~JS
        setTimeout(() => {
          document.querySelector('body').textContent = 'adjusted page'
        }, 2000)
      JS

      visit '/start'

      expect(page).to have_content('adjusted page')
    end

    it 'does not wait it the timeout is negative' do
      App.start_script = <<~JS
        setTimeout(() => {}, -1751537429808)
      JS

      visit '/start'

      busy = page.evaluate_script(<<~JS)
        CapybaraLockstep.isBusy()
      JS

      expect(busy).to be(false)
    end

    it 'calls stop work only once' do
      App.start_script = <<~JS
        let timeoutId = setTimeout(() => {
          clearTimeout(timeoutId);
        })
      JS

      visit '/start'

      busy = page.evaluate_script(<<~JS)
        CapybaraLockstep.isBusy()
      JS

      expect(busy).to be(false)
    end
  end
end
