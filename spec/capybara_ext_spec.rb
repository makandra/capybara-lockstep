describe Capybara::Lockstep::SynchronizeMacros do
  after do
    # called after each example, messes with our expectations
    allow(Capybara).to receive(:reset_sessions!)
  end

  let(:example_class) do
    Class.new do
      def do_something
      end

      def call_do_something
        do_something
      end
    end
  end

  describe 'synchronize_before' do
    let(:patched_class) do
      Class.new(example_class) do
        extend Capybara::Lockstep::SynchronizeMacros

        synchronize_before :call_do_something, lazy: false
      end
    end

    let(:patched_sub_class) do
      Class.new(patched_class) do
        extend Capybara::Lockstep::SynchronizeMacros

        synchronize_before :call_do_something, lazy: false
      end
    end

    it 'runs auto_synchronize before the method' do
      object = patched_class.new
      expect(Capybara::Lockstep).to receive(:auto_synchronize).exactly(:once).ordered
      expect(object).to receive(:do_something).ordered
      object.call_do_something
    end

    it 'runs it only once, even if we patch multiple classes in the class hierarchy' do
      object = patched_sub_class.new
      expect(Capybara::Lockstep).to receive(:auto_synchronize).exactly(:once).ordered
      expect(object).to receive(:do_something).ordered
      object.call_do_something
    end
  end

  describe 'synchronize_after' do
    let(:patched_class) do
      Class.new(example_class) do
        extend Capybara::Lockstep::SynchronizeMacros

        synchronize_after :call_do_something
      end
    end

    let(:patched_sub_class) do
      Class.new(patched_class) do
        extend Capybara::Lockstep::SynchronizeMacros

        synchronize_after :call_do_something
      end
    end

    it 'runs auto_synchronize before the method' do
      object = patched_class.new
      expect(object).to receive(:do_something).ordered
      expect(Capybara::Lockstep).to receive(:auto_synchronize).exactly(:once).ordered
      object.call_do_something
    end

    it 'runs it only once, even if we patch multiple classes in the class hierarchy' do
      object = patched_sub_class.new
      expect(object).to receive(:do_something).ordered
      expect(Capybara::Lockstep).to receive(:auto_synchronize).exactly(:once).ordered
      object.call_do_something
    end
  end

  describe 'synchronize_before and synchronize_after' do
    let(:patched_class) do
      Class.new(example_class) do
        extend Capybara::Lockstep::SynchronizeMacros

        synchronize_before :call_do_something, lazy: false
        synchronize_after :call_do_something
      end
    end

    it 'runs auto_synchronize before and after the method' do
      object = patched_class.new
      expect(Capybara::Lockstep).to receive(:auto_synchronize).exactly(:once).ordered
      expect(object).to receive(:do_something).ordered
      expect(Capybara::Lockstep).to receive(:auto_synchronize).exactly(:once).ordered
      object.call_do_something
    end
  end
end
