RSpec::Matchers.define :be_loaded_image do

  match do |selector_or_element|
    if selector_or_element.is_a?(String)
      element = page.find(selector_or_element)
    else
      element = selector_or_element
    end

    # Cannot just use the #complete property, as this is also true for broken image
    is_loaded = element.evaluate_script('this.complete && this.naturalWidth > 0')

    expect(is_loaded).to eq(true)
  end

end
