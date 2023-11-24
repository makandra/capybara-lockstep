describe 'spec setup' do

  it 'renders the app' do
    visit '/start'
    expect(page).to have_content('hi world')
  end

end
