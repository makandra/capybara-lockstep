describe Capybara::Lockstep do
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
