# frozen_string_literal: true

# Creating Custom Methods for FactoryBot
module FactoryHelper
  # Creates a {FactoryBot} object with customisation options.
  #
  # This method creates a {FactoryBot} object based on the specified model given a reference (fk),
  # traits (same as usual traits of {FactoryBot}) and additional options (same as usual).
  #
  # It supports creating objects with specific attributes from a reference object, as it can handle
  # associations, and it can also be used handle other scenarios to shorten method call using the.
  # metaprogramming methods generated from this module.
  #
  # @param model [Symbol] The symbol representing the {FactoryBot} model to use/create.
  # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
  # @param traits [Array<Symbol>] An array of {FactoryBot} traits to apply to the created object.
  # @param options [Hash] A hash of options to apply to the created object.
  #
  # @example Create an object without reference, and additional options.
  #   custom_create(:user_bank_account, traits: [:random], options: { first_name: 'Joseph' })
  #   => created <UserBankAccount> with first_name = 'Joseph' without any reference.
  #
  # @example Create an object with a reference that has records linked to model:
  #   user_reference = FactoryBot.create(:user)
  #   custom_create(:user_bank_account, reference: { user: user_reference }, traits: [:random])
  #   => created <UserBankAccount> that first tries to find a <User> that is already linked to
  #      this user_bank_account, and if not found, it creates a new <User> object.
  #
  # @raise ArgumentError if model is nil
  # @raise ArgumentError if reference is not a Hash
  # @raise ArgumentError if traits is not an Array
  # @raise ArgumentError if options is not a Hash
  #
  # @return [Object] The created {FactoryBot} object.
  #
  def custom_create(model, reference: {}, traits: [], options: {})
    raise ArgumentError, 'You must specify a model to use' if model.nil?
    raise ArgumentError, 'You must specify a valid hash of references to use' unless reference.is_a?(Hash)
    raise ArgumentError, 'You must specify valid array of traits to use' unless traits.is_a?(Array)
    raise ArgumentError, 'You must specify a valid hash of options to use' unless options.is_a?(Hash)

    return FactoryBot.create(model, *traits, options) if reference.empty?

    existing_reference = reference.values.first&.public_send(model.to_s.pluralize)&.sample
    return existing_reference if existing_reference

    options = options.merge(reference)
    FactoryBot.create(model, *traits, options)
  end

  # Prepares a polymorphic setting to be used in a Custom {FactoryBot} method.
  #
  # This method random selects one of the given models and forwards it to the original
  # {#custom_create} method.
  #
  # @param models [Array<Symbol>] Array of symbols, each representing a model that has a factory.
  # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
  # @param traits [Array<Symbol>] An array of {FactoryBot} traits to apply to the created object.
  # @param options [Hash] A hash of options to apply to the created object.
  #
  # @raise ArgumentError if reference is not an Array
  # @raise ArgumentError if models is an empty Array
  #
  # @see {#custom_create}
  #
  # @return [Object] The created {FactoryBot} object.
  #
  def custom_create_polymorphic(models, reference: {}, traits: [], options: {})
    raise ArgumentError, 'You must provide an array' unless models.is_a?(Array)
    raise ArgumentError, 'You must provide a non-empty array' if models.empty?

    custom_create(models.sample, reference:, traits:, options:)
  end

  %i[different random].map do |trait|
    # Metaprogramming to shorten method calls with traits.
    #
    # @param model [Symbol] The symbol representing the {FactoryBot} model to use/create.
    # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
    # @param options [Hash] A hash of options to apply to the created object.
    #
    # @see {#custom_create}
    #
    # @return [Object] The created {FactoryBot} object with the specified trait.
    #
    define_method("#{trait}_custom_create") do |model, reference: {}, options: {}|
      custom_create(model, reference:, traits: [trait], options:)
    end

    # Metaprogramming to shorten method calls with traits.
    #
    # @param models [Array<Symbol>] Array of symbols, each representing a model that has a factory.
    # @param reference [Hash] A hash representing the reference object from which attributes can be copied.
    # @param options [Hash] A hash of options to apply to the created object.
    #
    # @see {#custom_create_polymorphic}
    #
    # @return [Object] The created {FactoryBot} object with the specified trait.
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
