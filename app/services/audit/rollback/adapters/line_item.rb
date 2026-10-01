# frozen_string_literal: true

class Audit::Rollback::Adapters::LineItem < Audit::Rollback::Adapters::Base
  RECALCULATIONS = %w[category_transaction_totals cash_balance].freeze

  def support_issues
    parent_type, parent_id = parent_identity
    return [ issue(:missing_parent_identity) ] if parent_type.blank? || parent_id.blank?

    []
  end

  def dependencies
    return @dependencies if defined?(@dependencies)

    parent_type, parent_id = parent_identity
    return @dependencies = [] if parent_type.blank? || parent_id.blank?

    @dependencies = [
      dependency(record_type: parent_type, item_id: parent_id, relationship: :parent)
    ]
  end

  def recalculations
    RECALCULATIONS
  end

  private

  def parent_identity
    state = expected_after_state || before_state || {}
    [ state["transactable_type"], state["transactable_id"] ]
  end

  def dependency_available?(dependency)
    dependency.record_type.constantize.unscoped.exists?(id: dependency.item_id)
  rescue NameError
    false
  end

  def recreate_record!
    record = record_class.new(restore_attributes.merge("id" => item_id))
    record.skip_category_presence_validation = true
    record.save!
  end
end
