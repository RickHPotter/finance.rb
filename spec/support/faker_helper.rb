# frozen_string_literal: true

require "zlib"

module FakerHelper
  # Clears the Unique Generator
  #
  # @see https://github.com/faker-ruby/faker/blob/master/lib/faker/default/unique_generator.rb
  #
  def clear_faker_unique
    Faker::UniqueGenerator.clear
  end

  def deterministic_example_seed(example)
    Zlib.crc32("#{RSpec.configuration.seed}:#{example.id}")
  end

  def seed_example_randomness(example)
    seed = deterministic_example_seed(example)
    Kernel.srand(seed)
    Faker::Config.random = Random.new(seed)
  end
end

RSpec.configure do |config|
  config.include FakerHelper

  config.before(:example) do |example|
    clear_faker_unique
    seed_example_randomness(example)
  end
end
