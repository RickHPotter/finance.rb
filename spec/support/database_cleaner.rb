# frozen_string_literal: true

RSpec.configure do |config|
  config.after(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end
end
