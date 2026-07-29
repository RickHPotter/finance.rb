# frozen_string_literal: true

class Audit::Rollback::Adapters::UserCard < Audit::Rollback::Adapters::RoutingRecord
  DERIVED_ATTRIBUTES = (
    Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[card_transactions_count card_transactions_total]
  ).freeze
  RECALCULATIONS = %w[user_card_totals reference_payment_dates cash_balance].freeze

  def support_issues
    Card.exists?(id: historical_state["card_id"]) ? [] : [ issue(:missing_routing_catalog, record_type: "Card") ]
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
    %w[Reference CardTransaction CashTransaction]
  end

  def routing_foreign_key
    "user_card_id"
  end

  def live_dependent_identities
    [
      *Reference.where(user_card_id: item_id).ids.map { |id| [ "Reference", id ] },
      *CardTransaction.where(user_card_id: item_id).ids.map { |id| [ "CardTransaction", id ] },
      *CashTransaction.where(user_card_id: item_id).ids.map { |id| [ "CashTransaction", id ] }
    ]
  end

  def conflict_scope
    UserCard.unscoped.where(
      user_id: before_state["user_id"],
      card_id: before_state["card_id"],
      user_card_name: before_state["user_card_name"]
    )
  end
end
