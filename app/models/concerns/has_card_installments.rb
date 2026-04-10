# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module HasCardInstallments
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :original_installments, :original_installment_projection_rows

    # @relationships ..........................................................
    has_many :card_installments, dependent: :destroy
    accepts_nested_attributes_for :card_installments, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    before_destroy :remember_card_installments, prepend: true
    after_save :update_card_transaction_count_and_invoke_cash_transactable
  end

  # @public_class_methods .....................................................
  def card_installments_attributes=(attrs)
    snapshot_original_installments
    super
  end

  def card_installments=(attrs)
    snapshot_original_installments
    super
  end

  # @protected_instance_methods ...............................................

  protected

  def remember_card_installments
    snapshot_original_installments(scope: installments)
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

  def snapshot_original_installments(scope: card_installments)
    ordered_scope = scope.order(:number)

    self.original_installments = ordered_scope.map { |installment| installment.slice(:number, :year, :month, :price) }
    self.original_installment_projection_rows = ordered_scope.map { |installment| installment.slice(:number, :year, :month, :price, :cash_transaction_id) }
  end
end
