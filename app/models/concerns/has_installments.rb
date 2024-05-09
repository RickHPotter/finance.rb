# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module HasInstallments
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    has_many :installments, dependent: :destroy
    accepts_nested_attributes_for :installments, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    after_save :update_card_transaction_count
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets the `installments_count` of each record of `installments` based on the `installments_count` of given `self`.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def update_card_transaction_count
    installments_count = installments.count
    installments.each { |i| i.update(installments_count:) }
  end
end
