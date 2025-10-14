describe 'rack test', driver: :rack_test do

  it 'does not blow up' do
    App.start_html = <<~HTML
      <h1>Hallo App</h1>
      <a href="/next" onclick="fetch('/next')">To Next</a>
    HTML

    App.next_action = -> { <<~HTML }
      <h1>Hallo Next</h1>
      <label for="example-input">Some input</label>
      <input id="example-input"></input>
    HTML

    # Sanity check the driver config is correct
    expect(Capybara.current_driver).to eq :rack_test

    # Perform some random actions that would normally trigger a synchronization.
    # Since lockstep disables itself for rack_test, no synchronization should occur, which would trigger an error.
    # Thus, the key expectation here is that nothing is raised.
    expect do
      visit '/start'

      expect(Capybara::Lockstep.mode).to eq :off
      expect(page.html).to include "Hallo App"
      expect(page.find("h1").text).to eq "Hallo App"

      click_on "To Next"

      expect(page.html).to include "Hallo Next"

      page.refresh

      page.fill_in "Some input", with: "Foobar"

      expect(page.find_field("Some input").value).to eq "Foobar"

      Capybara::Lockstep.synchronize # Even manual synchronization is disabled here.
    end.not_to raise_error
  end

end
