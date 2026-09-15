# frozen_string_literal: true

require "rails_helper"

RSpec.describe FakerHelper do
  subject(:helper) { Object.new.extend(described_class) }

  it "derives stable per-example randomness from the suite seed and example id" do |example|
    first_seed = helper.deterministic_example_seed(example)

    helper.seed_example_randomness(example)
    first_values = [ rand(100_000), Faker::Number.number(digits: 5) ]
    helper.seed_example_randomness(example)
    second_values = [ rand(100_000), Faker::Number.number(digits: 5) ]

    expect(helper.deterministic_example_seed(example)).to eq(first_seed)
    expect(second_values).to eq(first_values)
  end
end
