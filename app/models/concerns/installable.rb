# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module Installable
  include Backend::MathsHelper
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :installment_attributes

    # @relationships ..........................................................
    has_many :installments, as: :installable

    # @callbacks ..............................................................
    before_validation :set_installments_count
    before_create :create_installments
    before_update :update_installments
  end

  # @protected_instance_methods ...............................................

  protected

  # Set `installments_count` to 1 if `installment_attributes` is blank.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_installments_count
    self.installments_count ||= 1 if installment_attributes.blank?
  end

  # Create installments based on the provided `installment_attributes` array of hashes.
  #
  # @example Create installments for a CardTransaction
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
  #   => create_installments is run after_save
  #   => 3 new installments are created, each with prices [38, 32, 30]
  #
  # @note The method uses the `installable` attribute along with the provided
  #   `installment_attributes` to create installments for the transactable.
  # @note This is a method that is called before_create.
  #
  # @return [void]
  #
  # @see Installment
  #
  def create_installments
    return create_default_installments if installment_attributes.blank?

    installment_attributes.each_with_index do |attributes, index|
      installments << Installment.create(attributes.merge(number: index + 1))
    end

    self.installments_count = installment_attributes.count
  end

  # Update installments based on the provided `installment_attributes` array of hashes.
  #
  # In all cases, there were installments, so these get destroyed, and then created again.
  # But if the amount of installments was not updated, then nothing happens unless
  # `installment_attributes` is not blank.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  def update_installments
    return if installments.count == installments_count && installment_attributes.blank?

    installments.destroy_all
    create_default_installments
  end

  # Create default installments for the CardTransaction when not previously created.
  #
  # This method uses {Backend::MathsHelper#spread_installments_evenly} to generate an array of prices evenly
  # distributed among the installments that are then created.
  #
  # @example Create default installments for a CardTransaction
  #   card_transaction = CardTransaction.create(installments_count: 3, price: 100, ...)
  #   => create_default_installments is run after being delegated from {#create_installments}
  #   => 3 new installments are created, each with prices [33.33, 33.33, 33.34]
  #
  # @note The method uses the `installments_count` attribute to determine the number
  #   of installments to create and distributes the total `price` evenly among them.
  #
  # @return [void]
  #
  def create_default_installments
    return if installments.present?

    prices_arr = spread_installments_evenly(price, installments_count)
    prices_arr.each_with_index do |price, number|
      installments << Installment.create(number: number + 1, price:, paid: false)
    end
  end
end
