# frozen_string_literal: true

class Audit::Rollback::Adapters::PiggyBank < Audit::Rollback::Adapters::Base
  RECALCULATIONS = %w[piggy_bank_projection investment_projection cash_balance].freeze
  PROJECTION_TYPES = %w[CashTransaction CashInstallment CategoryTransaction EntityTransaction].freeze

  def support_issues
    missing_keys = parent_identities.reject { |type, id| parent_available?(type, id) }.map { |type, id| "#{type}:#{id}" }
    missing_keys.present? ? [ issue(:missing_parent_dependency, dependencies: missing_keys) ] : []
  end

  def dependencies
    @dependencies ||= [
      *parent_identities.map { |type, id| dependency(record_type: type, item_id: id, relationship: :parent) },
      *investment_dependencies
    ].sort_by(&:key)
  end

  def recalculations
    RECALCULATIONS
  end

  def requirements
    return super unless paid_history?

    [ issue(:historical_correction_confirmation) ]
  end

  def compensate!(rows:, **)
    super(**)
    restore_projection_snapshots(rows)
    handled_destroyed_projection_keys(rows)
  end

  private

  def historical_state
    before_state || expected_after_state || {}
  end

  def parent_identities
    [
      [ "CashTransaction", historical_state["source_cash_transaction_id"] ],
      [ "CashTransaction", historical_state["return_cash_transaction_id"] ]
    ].select { |_type, id| id.present? }.uniq
  end

  def parent_available?(type, id)
    type.constantize.unscoped.exists?(id:) || transitions.any? do |candidate|
      candidate.record_type == type && candidate.item_id == id && candidate.before_state.present?
    end
  end

  def investment_dependencies
    return_ids.flat_map do |return_id|
      live_ids = Investment.where(piggy_bank_return_cash_transaction_id: return_id).ids
      historical_ids = transitions.filter_map do |candidate|
        next unless candidate.record_type == "Investment"

        states = [ candidate.before_state, candidate.expected_after_state ].compact
        candidate.item_id if states.any? { |state| state["piggy_bank_return_cash_transaction_id"] == return_id }
      end
      (live_ids + historical_ids).uniq.map do |investment_id|
        dependency(record_type: "Investment", item_id: investment_id, relationship: :dependent)
      end
    end
  end

  def return_ids
    [ before_state, expected_after_state, current_state ].compact.filter_map { |state| state["return_cash_transaction_id"] }.uniq
  end

  def restore_projection_snapshots(rows)
    projection_rows(rows).select { |row| row.record_type == "CashTransaction" && row.before_state.present? }.each do |row|
      record = CashTransaction.unscoped.find_by(id: row.item_id)
      next unless record

      attributes = row.before_state.slice("description", "starting_price", "price", "date", "month", "year", "paid")
      Audit::BulkMutation.update_columns!(record, attributes)
    end
    restore_projection_installments(rows)
  end

  def restore_projection_installments(rows)
    installment_rows = projection_rows(rows).select { |row| row.record_type == "CashInstallment" }
    return_ids.each do |return_id|
      expected_rows = installment_rows.select { |row| row.before_state&.fetch("cash_transaction_id", nil) == return_id }
      expected_ids = expected_rows.map(&:item_id)
      Audit::BulkMutation.delete_all!(CashInstallment.unscoped.where(cash_transaction_id: return_id, paid: false).where.not(id: expected_ids))
      expected_rows.each { |row| restore_installment(row) }
    end
  end

  def restore_installment(row)
    installment = CashInstallment.unscoped.find_by(id: row.item_id, installment_type: "CashInstallment")
    return installment.update!(row.adapter.restore_attributes) if installment

    CashInstallment.new(row.adapter.restore_attributes.merge("id" => row.item_id)).save!
  end

  def handled_destroyed_projection_keys(rows)
    return [] unless action == "destroy"

    projection_rows(rows).select do |row|
      row.action == "destroy" && !row.record_type.constantize.unscoped.exists?(id: row.item_id)
    end.map(&:key)
  end

  def projection_rows(rows)
    rows.select do |row|
      row.record_type.in?(PROJECTION_TYPES) && projection_row_for?(row)
    end
  end

  def projection_row_for?(row)
    return return_ids.include?(row.item_id) if row.record_type == "CashTransaction"

    [ row.before_state, row.expected_after_state ].compact.any? do |state|
      state["cash_transaction_id"].in?(return_ids) ||
        (state["transactable_type"] == "CashTransaction" && state["transactable_id"].in?(return_ids))
    end
  end

  def paid_history?
    return_ids.any? { |id| CashTransaction.unscoped.find_by(id:)&.paid_history? }
  end
end
