module Capybara
  module Lockstep
    describe Client do
      # Client is abstract; the driver-specific subclass provides the error handling.
      subject(:client) { Client::Selenium.new }

      describe '#synchronize' do
        context 'when the timeout is not positive' do
          before do
            Capybara::Lockstep.timeout = 0
          end

          it 'does not talk to the browser' do
            expect(client).to_not receive(:alert_present?)
            expect(client).to_not receive(:evaluate_async_script)

            client.synchronize
          end

          it 'leaves the client unsynchronized so the next call with a real timeout retries' do
            client.synchronized = true

            client.synchronize

            expect(client.synchronized?).to eq(false)
          end
        end

        context 'when the timeout is positive' do
          before do
            Capybara::Lockstep.timeout = 1
          end

          it 'synchronizes with the browser' do
            allow(Capybara::Lockstep).to receive(:unhandled_prompts_ignored?).and_return(false)
            allow(client).to receive(:alert_present?).and_return(false)
            expect(client).to receive(:evaluate_async_script).and_return('idle')

            client.synchronize

            expect(client.synchronized?).to eq(true)
          end

          context 'when configured to check for alerts' do
            before do
              Capybara::Lockstep.check_alerts = true
            end

            it 'does not synchronize while an alert is open' do
              allow(Capybara::Lockstep).to receive(:unhandled_prompts_ignored?).and_return(true)
              allow(client).to receive(:alert_present?).and_return(true)
              expect(client).to_not receive(:evaluate_async_script)

              client.synchronize

              expect(client.synchronized?).to eq(false)
            end
          end

          context 'when configured to not check for alerts' do
            before do
              Capybara::Lockstep.check_alerts = false
            end

            it 'synchronizes without checking for an open alert' do
              allow(Capybara::Lockstep).to receive(:unhandled_prompts_ignored?).and_return(false)
              expect(client).to_not receive(:alert_present?)
              expect(client).to receive(:evaluate_async_script).and_return('idle')

              client.synchronize

              expect(client.synchronized?).to eq(true)
            end
          end

          context 'when the alert check is not configured' do
            it 'checks for an open alert if the driver does not ignore unhandled prompts' do
              allow(Capybara::Lockstep).to receive(:unhandled_prompts_ignored?).and_return(false)
              expect(client).to receive(:alert_present?).and_return(true)
              expect(client).to_not receive(:evaluate_async_script)

              client.synchronize
            end

            it 'does not check for an open alert if the driver ignores unhandled prompts' do
              allow(Capybara::Lockstep).to receive(:unhandled_prompts_ignored?).and_return(true)
              expect(client).to_not receive(:alert_present?)
              expect(client).to receive(:evaluate_async_script).and_return('idle')

              client.synchronize

              expect(client.synchronized?).to eq(true)
            end
          end
        end
      end
    end
  end
end
