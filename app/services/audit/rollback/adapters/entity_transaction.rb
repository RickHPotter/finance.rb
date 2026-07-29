# frozen_string_literal: true

class Audit::Rollback::Adapters::EntityTransaction < Audit::Rollback::Adapters::Allocation
  ALLOCATION_FOREIGN_KEY = "entity_id"
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[exchanges_count]).freeze
  ENTITY_RECALCULATIONS = %w[entity_transaction_totals cash_balance].freeze

  def dependencies
    (super + exchange_dependencies).uniq(&:key).sort_by(&:key)
  end

  def recalculations
    ENTITY_RECALCULATIONS
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def exchange_dependencies
    exchange_ids.map do |exchange_id|
      dependency(record_type: "Exchange", item_id: exchange_id, relationship: :dependent)
    end
  end

  def exchange_ids
    current_ids = Exchange.where(entity_transaction_id: item_id).ids
    historical_ids = transitions.filter_map do |candidate|
      next unless candidate.record_type == "Exchange"

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      candidate.item_id if states.any? { |state| state["entity_transaction_id"] == item_id }
    end
    (current_ids + historical_ids).uniq.sort
  end
end
