# frozen_string_literal: true

class Audit::Rollback::Adapters::Investment < Audit::Rollback::Adapters::Base
  RECALCULATIONS = %w[investment_projection user_bank_account_totals cash_balance].freeze
  PROJECTION_TYPES = %w[CashTransaction CashInstallment CategoryTransaction EntityTransaction].freeze

  def support_issues
    issues = []
    issues << issue(:missing_routing_catalog, record_type: "InvestmentType") unless InvestmentType.exists?(id: historical_state["investment_type_id"])
    issues << issue(:missing_routing_catalog, record_type: "UserBankAccount") unless user_bank_account_available?
    issues << issue(:missing_investment_projection) if ordinary_investment? && projection_id.blank?
    issues << issue(:missing_piggy_bank_return) if piggy_bank_valuation? && !valid_piggy_bank_return?
    issues
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

  def historical_state
    before_state || expected_after_state || {}
  end

  def ordinary_investment?
    !piggy_bank_valuation?
  end

  def piggy_bank_valuation?
    historical_state["piggy_bank_return_cash_transaction_id"].present?
  end

  def projection_id
    historical_state["cash_transaction_id"]
  end

  def valid_piggy_bank_return?
    target = CashTransaction.unscoped.find_by(id: historical_state["piggy_bank_return_cash_transaction_id"])
    target&.user_id == owner_id && target&.context_id == context_id && target&.generated_piggy_bank_return?
  end

  def user_bank_account_available?
    account_id = historical_state["user_bank_account_id"]
    UserBankAccount.exists?(id: account_id) || transitions.any? do |candidate|
      candidate.record_type == "UserBankAccount" && candidate.item_id == account_id && candidate.before_state.present?
    end
  end

  def parent_identities
    identities = [ [ "UserBankAccount", historical_state["user_bank_account_id"] ] ]
    identities << [ "CashTransaction", projection_id ] if projection_id
    identities << [ "CashTransaction", historical_state["piggy_bank_return_cash_transaction_id"] ] if piggy_bank_valuation?
    identities.select { |_type, id| id.present? }.uniq
  end

  def restore_projection_snapshot(rows)
    projection_rows(rows).each do |row|
      next unless row.record_type == "CashTransaction" && row.before_state.present?

      record = CashTransaction.unscoped.find_by(id: row.item_id)
      next unless record

      attributes = row.before_state.slice("comment", "description", "price")
      Audit::BulkMutation.update_columns!(record, attributes)
    end
  end

  def handled_destroyed_projection_keys(rows)
    return [] unless action == "destroy"

    projection_rows(rows).select do |row|
      row.action == "destroy" && !row.record_type.constantize.unscoped.exists?(id: row.item_id)
    end.map(&:key)
  end

  def projection_rows(rows)
    projection_ids = [ projection_id, historical_state["piggy_bank_return_cash_transaction_id"] ].compact
    rows.select do |row|
      row.record_type.in?(PROJECTION_TYPES) &&
        projection_row_for?(row, projection_ids)
    end
  end

  def projection_row_for?(row, projection_ids)
    return projection_ids.include?(row.item_id) if row.record_type == "CashTransaction"

    states = [ row.before_state, row.expected_after_state ].compact
    states.any? do |state|
      state["cash_transaction_id"].in?(projection_ids) ||
        (state["transactable_type"] == "CashTransaction" && state["transactable_id"].in?(projection_ids))
    end
  end
end
