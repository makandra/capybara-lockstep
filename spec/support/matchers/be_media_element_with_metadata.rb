RSpec::Matchers.define :be_media_element_with_metadata do

  match(notify_expectation_failures: true) do |selector_or_element|
    if selector_or_element.is_a?(String)
      element = page.find(selector_or_element)
    else
      element = selector_or_element
    end

    ready_state = element.evaluate_script('this.readyState')

    expect(ready_state).to be >= 1
  end

end
