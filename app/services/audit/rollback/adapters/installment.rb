# frozen_string_literal: true

class Audit::Rollback::Adapters::Installment < Audit::Rollback::Adapters::Base
  DERIVED_ATTRIBUTES = (
    Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[balance order_id cash_installments_count card_installments_count]
  ).freeze
  CASH_RECALCULATIONS = %w[cash_installment_order cash_transaction_paid_state cash_balance].freeze
  CARD_RECALCULATIONS = %w[card_installment_cycles card_transaction_paid_state cash_balance].freeze

  def support_issues
    parent_type, parent_id = parent_identity
    return [ issue(:missing_parent_identity) ] if parent_type.blank? || parent_id.blank?

    []
  end

  def dependencies
    return @dependencies if defined?(@dependencies)

    parent_type, parent_id = parent_identity
    return @dependencies = [] if parent_type.blank? || parent_id.blank?

    @dependencies = [ dependency(record_type: parent_type, item_id: parent_id, relationship: :parent) ]
  end

  def recalculations
    record_type == "CashInstallment" ? CASH_RECALCULATIONS : CARD_RECALCULATIONS
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def find_current_record
    record_type.constantize.unscoped.find_by(id: item_id, installment_type: record_type)
  end

  def parent_identity
    state = expected_after_state || before_state || {}
    if record_type == "CashInstallment"
      [ "CashTransaction", state["cash_transaction_id"] || transition.versions.last.metadata["cash_transaction_id"] ]
    else
      [ "CardTransaction", state["card_transaction_id"] || transition.versions.last.metadata["card_transaction_id"] ]
    end
  end

  def dependency_available?(dependency)
    dependency.record_type.constantize.unscoped.exists?(id: dependency.item_id)
  end
end
