describe Capybara::Lockstep::Helper do

  it 'passes JavaScript specs' do
    require 'jasmine'
    Jasmine.load_configuration_from_yaml
    runner = Jasmine::CiRunner.new(Jasmine.config)
    expect(runner.run).to be_truthy, 'JavaScript specs failed'
  end

end
