namespace :spec do
  CAPYBARA_DRIVERS = %w[selenium cuprite]

  desc "Run all tests for all drivers"
  task :all do
    CAPYBARA_DRIVERS.each do |driver|
      run_specs driver
    end
  end

  CAPYBARA_DRIVERS.each do |driver|
    task driver do
      run_specs driver
    end
  end

  def run_specs(driver)
    puts "Running specs for using #{driver} as the capybara driver:\n"
    sh "CAPYBARA_DRIVER=#{driver} bundle exec rake spec"
  end

end
