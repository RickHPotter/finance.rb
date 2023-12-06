# frozen_string_literal: true

module FactoryHelper
  def custom_create(model:, reference:, traits: [])
    key = reference.keys.first
    value = reference.values.first

    return FactoryBot.create(model, *traits) if value.nil?

    model_plural = model.to_s.pluralize
    return value.public_send(model_plural).sample if value&.public_send(model_plural)&.present?

    FactoryBot.create(model, *traits, key => value)
  end
end

RSpec.configure do |config|
  config.include FactoryHelper
end

FactoryBot::SyntaxRunner.include FactoryHelper
