# frozen_string_literal: true

# Shared functionality for models that can produce Exchanges.
module HasExchanges
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    has_many :exchanges, dependent: :destroy
    accepts_nested_attributes_for :exchanges, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    before_save :update_entity_transaction_status
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets the `status` of the `entity_transaction` based on the existing `exchanges` and their `exchange_type`s.
  #
  # @note This is a method that is called before_save.
  #
  # @return [void].
  #
  def update_entity_transaction_status
    return self.status = :finished if exchanges.blank? || exchanges.map(&:exchange_type).uniq == [ "non_monetary" ]

    self.status = :pending
  end
end
