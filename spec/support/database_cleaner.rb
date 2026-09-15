# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.after(:example, :non_transactional) do
    DatabaseCleaner.clean_with(:truncation)
  end
end
