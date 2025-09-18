# frozen_string_literal: true

# Shared functionality for models that can produce CashTransaction Installments.
module HasCashInstallments
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :original_installments

    # @relationships ..........................................................
    has_many :cash_installments, dependent: :destroy
    accepts_nested_attributes_for :cash_installments, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    before_destroy :remember_cash_installments, prepend: true
    after_save :update_cash_transaction_count
  end

  # @public_class_methods .....................................................
  def cash_installments_attributes=(attrs)
    self.original_installments = cash_installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }
    super
  end

  def cash_installments=(attrs)
    self.original_installments = cash_installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }
    super
  end

  # @protected_instance_methods ...............................................

  protected

  def remember_cash_installments
    self.original_installments = installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }
  end

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
