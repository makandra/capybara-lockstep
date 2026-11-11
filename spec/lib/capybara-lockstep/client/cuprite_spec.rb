module Capybara
  module Lockstep
    describe Client::Cuprite do
      subject(:client) { described_class.new }

      describe '#with_synchronization_error_handling' do
        def synchronize_raising(error)
          client.with_synchronization_error_handling { raise error }
        end

        context 'when the browser navigated away while synchronizing' do
          it 'swallows a NoExecutionContextError (Ferrum 0.20+)' do
            error = ::Ferrum::NoExecutionContextError.new('message' => 'Cannot find context with specified id')

            expect { synchronize_raising(error) }.to_not raise_error
          end

          it 'swallows a NodeNotFoundError about an inspected target that navigated (Ferrum 0.20+)' do
            error = ::Ferrum::NodeNotFoundError.new('message' => 'Inspected target navigated or closed')

            expect { synchronize_raising(error) }.to_not raise_error
          end
        end

        context 'when an unrelated error occurs' do
          it 'reraises a BrowserError that is not about a closed window' do
            error = ::Ferrum::BrowserError.new('message' => 'Something went wrong')

            expect { synchronize_raising(error) }.to raise_error(error)
          end

          it 'reraises a NodeNotFoundError that is not about an inspected target that navigated' do
            error = ::Ferrum::NodeNotFoundError.new('message' => 'Could not find node with given id')

            expect { synchronize_raising(error) }.to raise_error(error)
          end
        end
      end
    end
  end
end
