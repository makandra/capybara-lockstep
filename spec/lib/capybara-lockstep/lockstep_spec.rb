module Capybara
  describe Lockstep do

    describe '#with_mode' do

      it 'uses a different mode for the duration of the block' do
        expect(Capybara::Lockstep.mode).to eq(:auto)
        block_spy = double('block spy')
        expect(block_spy).to receive(:observe).with(:manual)

        Capybara::Lockstep.with_mode(:manual) do
          block_spy.observe(Capybara::Lockstep.mode)
        end

        expect(Capybara::Lockstep.mode).to eq(:auto)
      end

      it 'reverts to the previous mode if the block crashes' do
        expect(Capybara::Lockstep.mode).to eq(:auto)

        expect do
          Capybara::Lockstep.with_mode(:manual) do
            raise "crashing block"
          end
        end.to raise_error("crashing block")

        expect(Capybara::Lockstep.mode).to eq(:auto)

      end

    end

    describe ".debug" do
      before { Capybara::Lockstep.debug = nil }
      after { Capybara::Lockstep.debug = nil }

      it "accepts true" do
        expect {
          Capybara::Lockstep.debug = true
        }.to output(/STDOUT/).to_stdout
      end

      it "accepts a logger" do
        Capybara::Lockstep.debug = Logger.new("/dev/null")
      end
    end

    describe '.check_alerts?' do
      it 'returns true when configured to check for alerts' do
        Capybara::Lockstep.check_alerts = true
        expect(Capybara::Lockstep.check_alerts?).to eq(true)
      end

      it 'returns false when configured to not check for alerts' do
        Capybara::Lockstep.check_alerts = false
        expect(Capybara::Lockstep.check_alerts?).to eq(false)
      end

      if Capybara.current_driver != :chrome_cuprite
        context 'when not configured' do
          def stub_unhandled_prompt_behavior(behavior)
            # Like Selenium does with the session's response, we keep the behavior as JSON.
            capabilities = ::Selenium::WebDriver::Remote::Capabilities.new(unhandled_prompt_behavior: behavior)
            allow(page.driver.browser).to receive(:capabilities).and_return(capabilities)
          end

          it 'returns false if the driver ignores prompts' do
            stub_unhandled_prompt_behavior('ignore')
            expect(Capybara::Lockstep.check_alerts?).to eq(false)
          end

          it 'returns true for other prompt behaviors' do
            stub_unhandled_prompt_behavior('dismiss and notify')
            expect(Capybara::Lockstep.check_alerts?).to eq(true)
          end

          it 'returns true when the driver reports no prompt behavior' do
            stub_unhandled_prompt_behavior(nil)
            expect(Capybara::Lockstep.check_alerts?).to eq(true)
          end

          it 'returns false for a map that ignores all prompts by default' do
            stub_unhandled_prompt_behavior({ 'default' => 'ignore' })
            expect(Capybara::Lockstep.check_alerts?).to eq(false)
          end

          it 'returns false for a map that ignores alerts, confirms and prompts' do
            stub_unhandled_prompt_behavior({ 'alert' => 'ignore', 'confirm' => 'ignore', 'prompt' => 'ignore' })
            expect(Capybara::Lockstep.check_alerts?).to eq(false)
          end

          it 'returns true for a map that handles one of alerts, confirms or prompts' do
            stub_unhandled_prompt_behavior({ 'default' => 'ignore', 'confirm' => 'accept' })
            expect(Capybara::Lockstep.check_alerts?).to eq(true)

            stub_unhandled_prompt_behavior({ 'alert' => 'ignore', 'confirm' => 'ignore' })
            expect(Capybara::Lockstep.check_alerts?).to eq(true)
          end
        end
      else
        it 'returns true when not configured' do
          expect(Capybara::Lockstep.check_alerts?).to eq(true)
        end
      end
    end

  end
end
