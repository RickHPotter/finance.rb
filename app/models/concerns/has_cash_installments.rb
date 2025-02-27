# frozen_string_literal: true

# Shared functionality for models that can produce CashTransaction Installments.
module HasCashInstallments
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    has_many :cash_installments, dependent: :destroy
    accepts_nested_attributes_for :cash_installments, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    after_save :update_cash_transaction_count
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets the `cash_installments_count` of each record of `cash_installments` based on the `cash_installments_count` of given `self`.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def update_cash_transaction_count
    cash_installments_count = cash_installments.count
    cash_installments.each { |i| i.update_columns(cash_installments_count:) }
  end
end
