# frozen_string_literal: true

module FakerHelper
  # Clears the Unique Generator
  #
  # @see https://github.com/faker-ruby/faker/blob/master/lib/faker/default/unique_generator.rb
  #
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
