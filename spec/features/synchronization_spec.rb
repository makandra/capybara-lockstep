describe 'synchronization' do

  it 'renders the app' do
    visit '/start'
    sleep 2
    expect(page).to have_content('hi world')
  end

end
