# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each, type: :request) do
    DatabaseCleaner.clean_with(:truncation)
  end
end
