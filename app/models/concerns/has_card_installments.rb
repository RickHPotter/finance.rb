# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module HasCardInstallments
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :original_installments

    # @relationships ..........................................................
    has_many :card_installments, dependent: :destroy
    accepts_nested_attributes_for :card_installments, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    before_destroy :remember_card_installments, prepend: true
    after_save :update_card_transaction_count_and_invoke_cash_transactable
  end

  # @public_class_methods .....................................................
  def card_installments_attributes=(attrs)
    self.original_installments = card_installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }
    super
  end

  def card_installments=(attrs)
    self.original_installments = card_installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }
    super
  end

  # @protected_instance_methods ...............................................

  protected

  def remember_card_installments
    self.original_installments = installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }
  end

  # Sets the `card_installments_count` of each record of `card_transaction.card_installments` based on the `card_installments_count` of given `self`.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def update_card_transaction_count_and_invoke_cash_transactable
    card_installments_count = card_installments.count
    card_installments.each { |i| i.update(card_installments_count:) if i.persisted? }
  end
end
