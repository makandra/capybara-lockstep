RSpec::Matchers.define :have_ready_state do |expected_ready_state|

  match(notify_expectation_failures: true) do |selector_or_element|
    if selector_or_element.is_a?(String)
      element = page.find(selector_or_element)
    else
      element = selector_or_element
    end

    ready_state = element.evaluate_script('this.readyState')

    expect(ready_state).to eq(expected_ready_state)
  end

end
