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

  end
end
