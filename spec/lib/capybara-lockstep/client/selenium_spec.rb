module Capybara
  module Lockstep
    describe Client::Selenium do
      subject(:client) { described_class.new }

      describe '#with_synchronization_error_handling' do
        def synchronize_raising(error)
          client.with_synchronization_error_handling { raise error }
        end

        # The browser can destroy the JS execution context that owns our pending async
        # probe (e.g. a Turbo frame swap or an SPA navigation). The promise can then never
        # resolve, and we treat that as a benign "navigated away" event: stay unsynchronized
        # and retry on the next Capybara synchronize call. Different Chrome/selenium versions
        # report this same condition with different error classes and messages.
        context 'when the browser navigated away while synchronizing' do
          it 'swallows a JavascriptError about an unloaded document (older Chrome/selenium)' do
            error = ::Selenium::WebDriver::Error::JavascriptError.new(
              'javascript error: document unloaded while waiting for result'
            )

            expect { synchronize_raising(error) }.to_not raise_error
          end

          it 'swallows an UnknownError about a collected promise (Chrome 141 / selenium 4.41)' do
            error = ::Selenium::WebDriver::Error::UnknownError.new(
              'unknown error: unhandled inspector error: {"code":-32000,"message":"Promise was collected"}'
            )

            expect { synchronize_raising(error) }.to_not raise_error
          end
        end

        context 'when an unrelated error occurs' do
          it 'reraises a JavascriptError that is not about an unloaded document' do
            error = ::Selenium::WebDriver::Error::JavascriptError.new(
              'javascript error: ReferenceError: foo is not defined'
            )

            expect { synchronize_raising(error) }.to raise_error(error)
          end

          it 'reraises an UnknownError that is not about a collected promise' do
            error = ::Selenium::WebDriver::Error::UnknownError.new(
              'unknown error: session deleted because of page crash'
            )

            expect { synchronize_raising(error) }.to raise_error(error)
          end
        end
      end
    end
  end
end
