class FakeCapybaraSession

  def evaluate_script(script)
  end

  def evaluate_async_script(script)
  end

  def execute_script(script)
  end

end

describe Capybara::Lockstep do

  subject do
    Capybara::Lockstep
  end

  def stub_page
    @page = FakeCapybaraSession.new
    allow(subject).to receive(:page).and_return(@page)
    # Prevent Capybara::Lockstep from disabling itself on non-JS drivers
    allow(subject).to receive(:javascript_driver?).and_return(true)
    allow(subject).to receive(:log)
  end

  after do
    subject.mode = nil
  end

  describe 'synchronize' do

    it 'calls the CapybaraLockstep.synchronize() function on the frontend' do
      stub_page
      expect(@page).to receive(:evaluate_async_script).with(match /CapybaraLockstep\.synchronize/)
      subject.synchronize
      expect(subject).to be_synchronized
    end

    it 'logs but does not fail when JavaScript communication fails due to an open alert' do
      stub_page
      error = Selenium::WebDriver::Error::UnexpectedAlertOpenError.new
      expect(@page).to receive(:evaluate_async_script).and_raise(error)
      expect(subject).to receive(:log).with(match /alert/i)
      expect { subject.synchronize }.to_not raise_error
      expect(subject).not_to be_synchronized
    end

    it 'logs but does not fail when the browser navigates to a new page while synchronizing' do
      stub_page
      error = Selenium::WebDriver::Error::JavascriptError.new('javascript error: document unloaded while waiting for result')
      expect(@page).to receive(:evaluate_async_script).and_raise(error)
      expect(subject).to receive(:log).with(match /navigated away/i)
      expect { subject.synchronize }.to_not raise_error
      expect(subject).not_to be_synchronized
    end

    it 'logs but does not fail when synchronization times out (we will retry on the next Capybara synchronize)' do
      stub_page
      error = Selenium::WebDriver::Error::ScriptTimeoutError.new
      expect(@page).to receive(:evaluate_async_script).and_raise(error)
      expect(subject).to receive(:log).with(match /could not synchronize within/i)
      expect { subject.synchronize }.to_not raise_error
      expect(subject).not_to be_synchronized
    end

    it 'logs but does not fail when the capybara-lockstep was not included in the page' do
      stub_page
      expect(@page).to receive(:evaluate_async_script).and_return(Capybara::Lockstep::ERROR_SNIPPET_MISSING)
      expect(subject).to receive(:log).with(Capybara::Lockstep::ERROR_SNIPPET_MISSING)
      expect { subject.synchronize }.to_not raise_error
      expect(subject).not_to be_synchronized
    end

    it "logs but does not fail when synchronizing before the initial Capybara visit" do
      stub_page
      expect(@page).to receive(:evaluate_async_script).and_return(Capybara::Lockstep::ERROR_PAGE_MISSING)
      expect(subject).to receive(:log).with(Capybara::Lockstep::ERROR_PAGE_MISSING)
      expect { subject.synchronize }.to_not raise_error
      expect(subject).not_to be_synchronized
    end

    it 're-raises an unknown error' do
      stub_page
      expect(@page).to receive(:evaluate_async_script).and_raise "unknown error"
      expect { subject.synchronize }.to raise_error("unknown error")
      expect(subject).not_to be_synchronized
    end

    it "does not synchronize when we're already synchronizing (as our own Capybara commands may cause recursive synchronization)" do
      stub_page
      allow(subject).to receive(:synchronizing?).and_return(true)
      expect(subject).not_to receive(:synchronize_now)
      subject.synchronize
    end

    describe 'with { lazy: true }' do

      it 'synchronizes when not synchronized' do
        stub_page
        subject.synchronized = false
        expect(subject).to receive(:synchronize_now)
        subject.synchronize(lazy: true)
      end

      it 'does not synchronize when synchronized' do
        stub_page
        subject.synchronized = true
        expect(subject).not_to receive(:synchronize_now)
        subject.synchronize(lazy: true)
      end

    end

    describe 'with mode = :off' do

      it 'does not synchronize' do
        stub_page
        subject.mode = :off
        expect(subject).not_to receive(:synchronize_now)
        subject.synchronize
      end

    end

    describe 'with mode = :auto' do

      it 'synchronizes' do
        stub_page
        subject.mode = :auto
        expect(subject).to receive(:synchronize_now)
        subject.synchronize
      end

    end

    describe 'with mode = :manual' do

      it 'synchronizes' do
        stub_page
        subject.mode = :manual
        expect(subject).to receive(:synchronize_now)
        subject.synchronize
      end

    end

  end

end
