# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module Installable
  extend ActiveSupport::Concern

  included do
    # @includes ...............................................................
    include Backend::MathsHelper

    # @security (i.e. attr_accessible) ........................................
    attr_accessor :installment_attributes

    # @relationships ..........................................................
    has_many :installments, as: :installable, dependent: :destroy

    # @callbacks ..............................................................
    before_validation :check_consistency
    before_validation :set_installments_count
    before_create :create_installments
    before_update :update_installments
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Checks the consistency of the atributes of `installments` creation.
  #
  # This method checks if the `installment_attributes` are present.
  # It then uses the {Backend::NestedHelper#check_array_of_hashes_of} method with the `installment_attributes`.
  # For each installment, it initialises a new {Installment} object based on the installment merged with
  # the `self`, which is an {CardTransaction}, as `transactable`.
  #
  # @return [Boolean] Returns true if all `installments` are valid; otherwise, it returns false with ActiveModel#errors.
  #
  def check_consistency
    return unless installment_attributes&.present?

    if installments_count != installment_attributes.size
      errors.add(:installments_count, 'The number of installments must match installments_count')
      return false
    end

    check_array_of_hashes_of(installments: installment_attributes) do |installment|
      inst = Installment.new(installment.merge(number: index + 1))
      true if inst.valid?
    end
  end

  # Sets `installments_count` to 1 if `installment_attributes` is blank.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_installments_count
    self.installments_count ||= 1 if installment_attributes.blank?
  end

  # Creates `installments` based on the provided `installment_attributes` array of hashes.
  #
  # @example Create `installments` for a {CardTransaction}
  #   card_transaction = CardTransaction.create(
  #     date: Date.current, user_id: User.first.id,
  #     user_card_id: User.first.user_cards.ids.sample,
  #     ct_description: 'testing', price: 100.00,
  #     month: Date.current.month, year: Date.current.year,
  #     installment_attributes: [
  #       { number: 1, price: 38.00 },
  #       { number: 2, price: 32.00 },
  #       { number: 2, price: 30.00 },
  #     ]
  #   )
  #   => 3 new installments are created, each with prices [38, 32, 30]
  #
  # @note This is a method that is called before_create.
  # @note The method uses the `installable` attribute along with the provided
  #   `installment_attributes` to create `installments` for the `transactable`.
  #
  # @see {Installment}
  #
  # @return [void]
  #
  def create_installments
    return create_default_installments if installment_attributes.blank?

    installment_attributes.each_with_index do |attributes, index|
      installments.push(Installment.new(attributes.merge(number: index + 1)))
    end

    self.installments_count = installment_attributes.count
    destroy_installment_attributes
  end

  # Updates `installments` based on the provided `installment_attributes` array of hashes.
  #
  # In case there were `installments` (always), these get destroyed.
  # If the amount of `installments` (through `installments_count` or `installment_attributes`)
  # was updated, then `installments` are created again. Otherwise, nothing happens.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  def update_installments
    return if installments.count == installments_count && installment_attributes.blank?

    installments.destroy_all
    create_default_installments

    destroy_installment_attributes
  end

  # Creates default `installments` for the CardTransaction in case installment_attributes are missing.
  #
  # This method uses {Backend::MathsHelper#spread_installments_evenly} to generate an array of prices
  # evenly distributed among the `installments` that are then created.
  #
  # @example Create default `installments` for a {CardTransaction}
  #   card_transaction = CardTransaction.create(installments_count: 3, price: 100, ...)
  #   => create_default_installments is run after being delegated from {#create_installments}
  #   => 3 new installments are created, each with prices [33.33, 33.33, 33.34]
  #
  # @note The method uses the `installments_count` attribute to determine the number
  #   of `installments` to create and distributes the total `price` evenly among them.
  #
  # @return [void]
  #
  def create_default_installments
    return if installments.present?

    prices_arr = spread_installments_evenly(price, installments_count)
    prices_arr.each_with_index do |price, number|
      installments.push(Installment.new(number: number + 1, price:, paid: false))
    end
  end

  # Destroys `installment_attributes` so that later updates don't reuse the cached instance
  #
  def destroy_installment_attributes
    self.installment_attributes = nil
  end
end
