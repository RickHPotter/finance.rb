# frozen_string_literal: true

# Creating Custom Methods for FactoryBot
module FactoryHelper
  # Creates a FactoryBot object with customisation options.
  #
  # This method creates a FactoryBot object based on the specified model with optional traits and a reference.
  # It supports creating objects with specific attributes from a reference object, and it can handle associations.
  #
  # @param model [Symbol] The symbol representing the FactoryBot model to create.
  # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
  # @param traits [Array<Symbol>] An array of FactoryBot traits to apply to the created object.
  #
  # @example Creating an object without reference.
  #   custom_create(model: :user_bank_account, traits: [:random])
  #   => created <UserBankAccount> without any reference
  #
  # @example Creating an object with a reference that has records linked to model:
  #   user_reference = FactoryBot.create(:user)
  #   custom_create(model: :user_bank_account, reference: user_reference, traits: [:random])
  #   => existing <UserBankAccount> that belongs to the <User> object
  #
  # @example Creating an object with a reference that has no records linked to model:
  #   user_reference = FactoryBot.create(:user)
  #   custom_create(model: :user_bank_account, reference: user_reference, traits: [:random])
  #   => created <UserBankAccount> that belongs to the <User> object
  #
  # @return [Object] The created FactoryBot object.
  #
  def custom_create(model:, reference:, traits: [])
    key = reference.keys.first
    value = reference.values.first

    return FactoryBot.create(model, *traits) if value.nil?

    model_plural = model.to_s.pluralize
    return value.public_send(model_plural).sample if value&.public_send(model_plural)&.present?

    FactoryBot.create(model, *traits, key => value)
  end
end

module FactoryBot
  class DefinitionProxy
    include FactoryHelper
  end

  class SyntaxRunner
    include FactoryHelper
  end
end
