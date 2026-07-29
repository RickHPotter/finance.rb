# frozen_string_literal: true

class Audit::Rollback::Adapters::UserBankAccount < Audit::Rollback::Adapters::RoutingRecord
  DERIVED_ATTRIBUTES = (
    Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[balance cash_transactions_count cash_transactions_total]
  ).freeze
  RECALCULATIONS = %w[user_bank_account_totals cash_balance].freeze

  def support_issues
    Bank.exists?(id: historical_state["bank_id"]) ? [] : [ issue(:missing_routing_catalog, record_type: "Bank") ]
  end

  def recalculations
    RECALCULATIONS
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def historical_state
    before_state || expected_after_state || {}
  end

  def dependent_types
    %w[CashTransaction Investment]
  end

  def routing_foreign_key
    "user_bank_account_id"
  end

  def live_dependent_identities
    [
      *CashTransaction.where(user_bank_account_id: item_id).ids.map { |id| [ "CashTransaction", id ] },
      *Investment.where(user_bank_account_id: item_id).ids.map { |id| [ "Investment", id ] }
    ]
  end

  def conflict_scope
    UserBankAccount.unscoped.where(
      bank_id: before_state["bank_id"],
      agency_number: before_state["agency_number"],
      account_number: before_state["account_number"]
    )
  end
end
