# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module Installable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :installment_attributes

    # @relationships ..........................................................
    has_many :installments, as: :installable

    # @callbacks ..............................................................
    before_validation :set_installments_count
    after_save :create_installments
    after_update :update_installments
  end

  # @protected_instance_methods ...............................................

  protected

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

  def update_installments
    return if installments.count == installments_count

    installments.destroy_all
    return create_default_installments if installment_attributes.blank?

    create_installments
  end

  # Create default installments for the CardTransaction when not previously created.
  #
  # This method uses {#calculate_installments} to generate an array of prices evenly
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

    prices_arr = calculate_installments(price, installments_count)
    prices_arr.each_with_index do |price, number|
      installments << Installment.create(number: number + 1, price:, paid: false)
    end
  end

  # Calculate the prices for each installment.
  #
  # @param price [BigDecimal] The total price of the CardTransaction.
  # @param count [Integer] The number of installments to create.
  #
  # @return [Array<BigDecimal>] An array containing the prices for each installment.
  #
  def calculate_installments(price, count)
    base = (price / count.to_f).round(2)
    remainder = (base + (price - (base * count))).round(2)

    [base] * (count - 1) + [remainder]
  end
end
