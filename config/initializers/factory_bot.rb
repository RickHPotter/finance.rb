# frozen_string_literal: true

# Creating Custom Methods for FactoryBot
module FactoryHelper
  # Creates a FactoryBot object with customisation options.
  #
  # This method creates a FactoryBot object based on the specified model
  # given a reference (fk), traits and additional optionals.
  # It supports creating objects with specific attributes from a reference
  # object, and it can handle associations.
  #
  # @param model [Symbol] The symbol representing the FactoryBot model to use/create.
  # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
  # @param traits [Array<Symbol>] An array of FactoryBot traits to apply to the created object.
  # @param options [Hash] A hash of options to apply to the created object.
  #
  # @example Creating an object without reference, and additional options.
  #   custom_create(:user_bank_account, traits: [:random], options: { first_name: 'Joseph' })
  #   => created <UserBankAccount> with first_name = 'Joseph' without any reference
  #
  # @example Creating an object with a reference that has records linked to model:
  #   user_reference = FactoryBot.create(:user)
  #   custom_create(:user_bank_account, reference: { user: user_reference }, traits: [:random])
  #   => existing <UserBankAccount> that belongs to the <User> object
  #
  # @example Creating an object with a reference that has no records linked to model:
  #   user_reference = FactoryBot.create(:user)
  #   custom_create(:user_bank_account, reference:  { user: user_reference  }, traits: [:random])
  #   => created <UserBankAccount> that belongs to the <User> object
  #
  # @raise ArgumentError if model is nil
  # @raise ArgumentError if reference is not a Hash
  #
  # @return [Object] The created FactoryBot object.
  #
  def custom_create(model, reference: {}, traits: [], options: {})
    raise ArgumentError, 'You must specify a model to use' if model.nil?
    raise ArgumentError, 'You must specify a valid reference to use' unless reference.is_a?(Hash)

    return FactoryBot.create(model, *traits) if reference.empty?

    key = reference.keys.first
    value = reference.values.first

    model_plural = model.to_s.pluralize
    return value.public_send(model_plural).sample if value&.public_send(model_plural)&.present?

    options = options.merge(key => value)
    FactoryBot.create(model, *traits, options)
  end

  # Prepares a polymorphic setting to be used in a Custom FactoryBot method.
  #
  # This method random selects one of the given models and forwards it to the original
  # {#custom_create} method.
  #
  # @param models [Array<Symbol>] Array of symbols, each representing a valid FactoryBot model to use/create.
  # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
  # @param traits [Array<Symbol>] An array of FactoryBot traits to apply to the created object.
  # @param options [Hash] A hash of options to apply to the created object.
  #
  # @raise ArgumentError if models is not an array or is empty
  #
  # @return [Object] The created FactoryBot object.
  #
  # @see {#custom_create}
  #
  def custom_create_polymorphic(models, reference: {}, traits: [], options: {})
    raise ArgumentError, 'You must provide a non-empty array' unless models.is_a?(Array) && !models.empty?

    custom_create(models.sample, reference:, traits:, options:)
  end

  %i[different random].map do |trait|
    # Metaprogramming to shorten method calls with traits.
    #
    # @param model [Symbol] The symbol representing the FactoryBot model to use/create.
    # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
    # @param traits [Array<Symbol>] An array of FactoryBot traits to apply to the created object.
    # @param options [Hash] A hash of options to apply to the created object.
    #
    # @return [Object] The created FactoryBot object with the specified trait.
    #
    # @see {#custom_create}
    #
    define_method("#{trait}_custom_create") do |model, reference: {}, options: {}|
      custom_create(model, reference:, traits: [trait], options:)
    end

    # Metaprogramming to shorten method calls with traits.
    #
    # @param models [Array<Symbol>] Array of symbols, each representing a valid FactoryBot model to use/create.
    # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
    # @param traits [Array<Symbol>] An array of FactoryBot traits to apply to the created object.
    # @param options [Hash] A hash of options to apply to the created object.
    #
    # @return [Object] The created FactoryBot object with the specified trait.
    #
    # @see {#custom_create_polymorphic}
    #
    define_method("#{trait}_custom_create_polymorphic") do |models, reference: {}, options: {}|
      custom_create_polymorphic(models, reference:, traits: [trait], options:)
    end
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
