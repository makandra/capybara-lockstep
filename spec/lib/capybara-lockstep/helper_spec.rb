module Capybara
  module Lockstep
    describe Helper do

      subject do
        object = Object.new
        object.extend(Helper)
        object
      end

      describe '#capybara_lockstep_js' do

        it 'returns the CapybaraLockstep helper' do
          expect(subject.capybara_lockstep_js).to include('window.CapybaraLockstep =')
        end

        it 'configures a custom #wait_tasks setting' do
          expect(subject.capybara_lockstep_js).to_not include('CapybaraLockstep.waitTasks')

          Lockstep.wait_tasks = 99

          expect(subject.capybara_lockstep_js).to include('CapybaraLockstep.waitTasks = 99')
        end

        it 'configures a custom #debug setting' do
          expect(subject.capybara_lockstep_js).to_not include('CapybaraLockstep.debug')

          Lockstep.debug = true

          expect(subject.capybara_lockstep_js).to include('CapybaraLockstep.debug = true')

        end

      end

    end
  end
end
