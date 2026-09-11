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

      unless Capybara.current_driver == :chrome_cuprite
        # There seems to be a bug in cuprite/ferrum which does not allow us to insert a lazy iframe out of view.
        # https://github.com/rubycdp/cuprite/issues/303

        it 'does not wait for an iframe with [loading=lazy]' do
          App.start_html = <<~HTML
          <a href="#" onclick="
            let iframe = document.createElement('iframe');
            iframe.setAttribute('loading', 'lazy');
            iframe.src = '/next';
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

    if Capybara.current_driver != :chrome_cuprite
      # Alerts never stay open with cuprite, there is no option to configure this.

      it 'does not close an alert that was opened on click' do
        App.start_html = <<~HTML
          <a href="#" onclick="confirm('OK to proceed?')">label</a>
        HTML

        visit '/start'
        page.find('a').click
        page.accept_confirm('OK to proceed?')
      end
    end

    it 'does handle alerts with accept_confirm using a block to open the alert' do
      App.start_html = <<~HTML
        <a href="#" onclick="confirm('OK to proceed?')">label</a>
      HTML

      visit '/start'
      message = accept_confirm do
        page.find('a').click
      end
      expect(message).to eq 'OK to proceed?'
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

  describe 'nested lookups in filter blocks' do

    # Capybara evaluates filter blocks with `using_wait_time(0)`. Our default timeout
    # is Capybara.default_max_wait_time, so a lazy synchronization triggered by a nested
    # lookup would run with a timeout of 0. Capybara's Selenium driver persists that 0
    # as the WebDriver script timeout, which broke every later script-based command
    # with a Selenium::WebDriver::Error::ScriptTimeoutError.
    def expect_nested_lookup_to_work
      # The bug only appears with the default timeout, which falls back to
      # Capybara.default_max_wait_time and is therefore 0 inside a filter block.
      Capybara::Lockstep.timeout = nil

      result = page.has_css?('body') { |body| body.has_css?('#content') }
      expect(result).to eq(true)

      # Capybara's visibility check runs a script in the browser.
      expect(page).to have_css('body')

      if Capybara::Lockstep.selenium_driver?
        # Capybara's Selenium driver stores the wait time as the WebDriver script timeout,
        # which outlives the call that set it. Make sure it was not left at 0.
        expect(page.driver.browser.manage.timeouts.script_timeout).to be > 0
      elsif Capybara::Lockstep.cuprite_driver?
        # Cuprite passes the wait time to each evaluate_async call as a setTimeout inside
        # the script. A timeout of 0 only fails that one call and leaves no state behind,
        # so there is nothing to check.
      else
        raise Capybara::Lockstep::DriverNotSupportedError, "The driver #{page.driver.class.name} is not supported by capybara-lockstep."
      end
    end

    it 'does not break the browser when the client is out of sync because of pending work' do
      App.start_html = <<~HTML
        <div id="content">content</div>
      HTML

      App.start_script = <<~JS
        CapybaraLockstep.startWork('never finishes')
      JS

      visit '/start'

      expect_nested_lookup_to_work
    end

    it 'does not break the browser when the client is out of sync because the snippet is missing' do
      visit '/without_snippet'

      expect_nested_lookup_to_work
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

end
