# frozen_string_literal: true

class Audit::Rollback::Adapters::Budget < Audit::Rollback::Adapters::Base
  DERIVED_ATTRIBUTES = (
    Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[balance order_id remaining_value]
  ).freeze
  RECALCULATIONS = %w[budget_remaining_value cash_balance].freeze
  COMPANION_TYPES = {
    "BudgetCategory" => :budget_categories,
    "BudgetEntity" => :budget_entities
  }.freeze

  def support_issues
    return [] unless action == "recreate"
    return [] if companion_transitions.any? { |candidate| candidate.before_state.present? }

    [ issue(:incomplete_budget_graph) ]
  end

  def dependencies
    @dependencies ||= companion_transitions.map do |candidate|
      dependency(record_type: candidate.record_type, item_id: candidate.item_id, relationship: :dependent)
    end.sort_by(&:key)
  end

  def recalculations
    RECALCULATIONS
  end

  def compensate!(rows:, handled_keys:, **)
    companion_rows = rows.select { |row| companion_transition?(row.transition) && handled_keys.exclude?(row.key) }

    case action
    when "destroy" then destroy_record!
    when "recreate" then recreate_budget!(companion_rows)
    when "update" then update_budget!(companion_rows)
    end

    companion_rows.map(&:key)
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def companion_transitions
    @companion_transitions ||= transitions.select { |candidate| companion_transition?(candidate) }
  end

  def companion_transition?(candidate)
    return false unless candidate.record_type.in?(COMPANION_TYPES.keys)

    [ candidate.before_state, candidate.expected_after_state ].compact.any? { |state| state["budget_id"] == item_id }
  end

  def recreate_budget!(rows)
    budget = record_class.new(restore_attributes.merge("id" => item_id))
    rows.select { |row| row.before_state.present? }.each { |row| build_companion(budget, row) }
    prepare_budget(budget)
    budget.save!
  end

  def update_budget!(rows)
    raise ActiveRecord::RecordNotFound, "Budget #{item_id} is missing" unless live_record

    live_record.assign_attributes(restore_attributes)
    rows.each { |row| apply_companion(live_record, row) }
    prepare_budget(live_record)
    live_record.save!
  end

  def apply_companion(budget, row)
    association = budget.public_send(COMPANION_TYPES.fetch(row.record_type))
    case row.action
    when "destroy" then association.detect { |record| record.id == row.item_id }&.mark_for_destruction
    when "recreate" then build_companion(budget, row)
    when "update" then association.detect { |record| record.id == row.item_id }&.assign_attributes(row.adapter.restore_attributes)
    end
  end

  def build_companion(budget, row)
    association = budget.public_send(COMPANION_TYPES.fetch(row.record_type))
    association.build(row.adapter.restore_attributes.merge("id" => row.item_id))
  end

  def prepare_budget(budget)
    budget.recalculate_balance = false
  end
end
