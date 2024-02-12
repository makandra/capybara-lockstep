RSpec::Matchers.define :be_broken_image do

  match do |selector_or_element|
    if selector_or_element.is_a?(String)
      element = page.find(selector_or_element)
    else
      element = selector_or_element
    end

    is_broken = element.evaluate_script('this.complete && this.naturalWidth === 0')

    expect(is_broken).to eq(true)
  end

end
