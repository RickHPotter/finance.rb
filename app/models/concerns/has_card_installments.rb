# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module HasCardInstallments
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    has_many :card_installments, dependent: :destroy
    accepts_nested_attributes_for :card_installments, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    after_initialize :create_one_default_card_installment
    after_save :update_card_transaction_count
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Initialises the `card_installments` of a newly created `card_transaction`.
  #
  # @note This is a method that is called after_initialize.
  #
  # @return [void].
  #
  def create_one_default_card_installment
    card_installments.new(number: 1, price:) if card_installments.empty?
  end

  # Sets the `card_installments_count` of each record of `card_transaction.card_installments` based on the `card_installments_count` of given `self`.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def update_card_transaction_count
    card_installments_count = card_installments.count
    card_installments.each { |i| i.update(card_installments_count:) }
  end
end
