# frozen_string_literal: true

# Validates rich normal-form allocation changes before existing domain callbacks
# coordinate exchanges, shared returns, subscriptions, and Piggy Bank projections.
module FormAllocationCoordinatable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :subscription_allocation_sync

    # @validations ............................................................
    validate :validate_form_allocation_coordination

    # @callbacks ..............................................................
    after_commit :coordinate_form_allocation_domains
    after_commit :clear_subscription_allocation_sync
  end

  private

  def validate_form_allocation_coordination
    coordinator = AllocationMutations::FormCoordinator.new(
      owner: self,
      entity_attributes: submitted_entity_transaction_attributes
    ).call

    coordinator.errors.each do |error|
      errors.add(:base, error.code, **error.details)
    end

    @coordinate_piggy_bank_entity_allocation = piggy_bank_entity_allocation_changed? if coordinator.valid?
  end

  def coordinate_form_allocation_domains
    return unless @coordinate_piggy_bank_entity_allocation

    entity_transactions.reload
    piggy_bank.sync_return_projection!
  ensure
    @coordinate_piggy_bank_entity_allocation = false
  end

  def piggy_bank_entity_allocation_changed?
    return false unless is_a?(CashTransaction)
    return false unless persisted? && piggy_bank.present? && !piggy_bank.paid_history?
    return false if original_entities.nil?

    final_entity_ids = entity_transactions.reject(&:marked_for_destruction?).filter_map(&:entity_id).map(&:to_i).sort
    Array(original_entities).map(&:to_i).sort != final_entity_ids
  end

  def clear_subscription_allocation_sync
    self.subscription_allocation_sync = nil
  end
end
