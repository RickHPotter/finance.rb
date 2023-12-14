# frozen_string_literal: true

module FakerHelper
  def clear_faker_unique
    Faker::UniqueGenerator.clear
  end
end

RSpec.configure do |config|
  config.include FakerHelper

  config.before(:example) do
    clear_faker_unique
  end
end
