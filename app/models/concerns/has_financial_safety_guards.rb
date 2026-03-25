# frozen_string_literal: true

# Shared write-layer guards for transactions backed by installments.
module HasFinancialSafetyGuards
  extend ActiveSupport::Concern

  included do
    # @validations ............................................................
    validate :prevent_unsafe_paid_history_rewrites, on: :update

    # @callbacks ..............................................................
    before_destroy :prevent_destroy_when_paid_history_is_locked, prepend: true
  end

  # @private_instance_methods .................................................

  private

  def prevent_unsafe_paid_history_rewrites
    return unless persisted?
    return unless paid_history?

    add_allocation_history_error if allocation_changed_after_payment?
    add_installment_history_error if unsafe_installment_rewrite_attempted?
  end

  def prevent_destroy_when_paid_history_is_locked
    return if can_destroy_with_history?

    errors.add(:base, destroy_history_error_key)
    throw(:abort)
  end

  def unsafe_installment_rewrite_attempted?
    return false unless parent_financial_fields_changed? || installment_structure_changed?
    return true if paid_installment_rewrite_attempted?

    !can_edit_unpaid_future_installments?(editable_installment_dates)
  end

  def allocation_changed_after_payment?
    return false unless original_categories.present? || original_entities.present?

    !can_change_allocation? && allocation_changed?
  end

  def allocation_changed?
    original_category_ids != current_category_ids || original_entity_ids != current_entity_ids
  end

  def installment_structure_changed?
    installments.any? { |installment| installment.marked_for_destruction? || installment.new_record? || installment.changed? }
  end

  def paid_installment_rewrite_attempted?
    installments.any? do |installment|
      next false unless installment.persisted? && installment.paid?

      installment.marked_for_destruction? || installment.changed?
    end
  end

  def editable_installment_dates
    installments.filter_map do |installment|
      next if installment.persisted? && installment.paid?
      next if installment.marked_for_destruction?

      installment.date
    end
  end

  def parent_financial_fields_changed?
    will_save_change_to_date? || will_save_change_to_month? || will_save_change_to_year? || will_save_change_to_price?
  end

  def original_category_ids
    Array(original_categories).presence || current_category_ids
  end

  def original_entity_ids
    Array(original_entities).presence || current_entity_ids
  end

  def current_category_ids
    category_transactions.map(&:category_id).compact.sort
  end

  def current_entity_ids
    entity_transactions.map(&:entity_id).compact.sort
  end

  def add_allocation_history_error
    errors.add(:base, allocation_history_error_key)
  end

  def add_installment_history_error
    errors.add(:base, installment_history_error_key)
  end

  def allocation_history_error_key
    :allocation_locked_after_payment
  end

  def installment_history_error_key
    :paid_history_locked
  end

  def destroy_history_error_key
    :destroy_locked_after_payment
  end
end
