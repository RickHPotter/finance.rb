# frozen_string_literal: true

class Audit::Rollback::Adapters::Exchange < Audit::Rollback::Adapters::Base
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[exchanges_count]).freeze
  RECALCULATIONS = %w[exchange_projection entity_transaction_status cash_balance].freeze
  PROJECTION_TYPES = %w[CashTransaction CashInstallment CategoryTransaction EntityTransaction].freeze

  def support_issues
    return [] if entity_transaction_available?

    [ issue(:missing_parent_dependency, dependencies: [ "EntityTransaction:#{historical_state['entity_transaction_id']}" ]) ]
  end

  def dependencies
    @dependencies ||= parent_identities.map do |parent_type, parent_id|
      dependency(record_type: parent_type, item_id: parent_id, relationship: :parent)
    end.sort_by(&:key)
  end

  def recalculations
    RECALCULATIONS
  end

  def compensate!(rows:, **)
    super(**)
    restore_projection_snapshot(rows)
    handled_destroyed_projection_keys(rows)
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def historical_state
    before_state || expected_after_state || {}
  end

  def parent_identities
    [
      [ "EntityTransaction", historical_state["entity_transaction_id"] ],
      [ "CashTransaction", historical_state["cash_transaction_id"] ]
    ].select { |_type, id| id.present? }.uniq
  end

  def entity_transaction_available?
    entity_transaction_id = historical_state["entity_transaction_id"]
    EntityTransaction.exists?(id: entity_transaction_id) || transitions.any? do |candidate|
      candidate.record_type == "EntityTransaction" && candidate.item_id == entity_transaction_id && candidate.before_state.present?
    end
  end

  def restore_projection_snapshot(rows)
    projection_rows(rows).each do |row|
      next unless row.record_type == "CashTransaction" && row.before_state.present?

      record = CashTransaction.unscoped.find_by(id: row.item_id)
      Audit::BulkMutation.update_columns!(record, row.before_state.slice("description", "starting_price", "price", "date", "month", "year", "paid")) if record
    end
    restore_projection_installments(rows)
  end

  def restore_projection_installments(rows)
    installment_rows = projection_rows(rows).select { |row| row.record_type == "CashInstallment" }
    projection_ids = installment_rows.flat_map do |row|
      [ row.before_state, row.expected_after_state ].compact.filter_map { |state| state["cash_transaction_id"] }
    end.uniq

    projection_ids.each do |projection_id|
      expected_rows = installment_rows.select { |row| row.before_state&.fetch("cash_transaction_id", nil) == projection_id }
      expected_ids = expected_rows.map(&:item_id)
      Audit::BulkMutation.delete_all!(CashInstallment.unscoped.where(cash_transaction_id: projection_id, paid: false).where.not(id: expected_ids))
      expected_rows.each { |row| restore_installment(row) }
    end
  end

  def restore_installment(row)
    installment = CashInstallment.unscoped.find_by(id: row.item_id, installment_type: "CashInstallment")
    if installment
      installment.update!(row.adapter.restore_attributes)
    else
      CashInstallment.new(row.adapter.restore_attributes.merge("id" => row.item_id)).save!
    end
  end

  def handled_destroyed_projection_keys(rows)
    return [] unless action == "destroy"

    projection_rows(rows).select do |row|
      row.action == "destroy" && !row.record_type.constantize.unscoped.exists?(id: row.item_id)
    end.map(&:key)
  end

  def projection_rows(rows)
    projection_id = historical_state["cash_transaction_id"]
    return [] unless projection_id

    rows.select do |row|
      row.record_type.in?(PROJECTION_TYPES) && projection_row_for?(row, projection_id)
    end
  end

  def projection_row_for?(row, projection_id)
    return row.item_id == projection_id if row.record_type == "CashTransaction"

    [ row.before_state, row.expected_after_state ].compact.any? do |state|
      state["cash_transaction_id"] == projection_id ||
        (state["transactable_type"] == "CashTransaction" && state["transactable_id"] == projection_id)
    end
  end
end
