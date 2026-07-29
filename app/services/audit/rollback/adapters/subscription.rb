# frozen_string_literal: true

class Audit::Rollback::Adapters::Subscription < Audit::Rollback::Adapters::Base
  DERIVED_ATTRIBUTES = (
    Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[card_transactions_count cash_transactions_count price]
  ).freeze
  RECALCULATIONS = %w[subscription_totals cash_balance].freeze
  DEPENDENT_TYPES = %w[CashTransaction CardTransaction CategoryTransaction EntityTransaction].freeze

  def dependencies
    @dependencies ||= dependent_identities.map do |dependent_type, dependent_id|
      dependency(record_type: dependent_type, item_id: dependent_id, relationship: :dependent)
    end.sort_by(&:key)
  end

  def recalculations
    RECALCULATIONS
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def dependent_identities
    (live_dependent_identities + historical_dependent_identities).uniq.sort
  end

  def live_dependent_identities
    [
      *CashTransaction.where(subscription_id: item_id).ids.map { |id| [ "CashTransaction", id ] },
      *CardTransaction.where(subscription_id: item_id).ids.map { |id| [ "CardTransaction", id ] },
      *CategoryTransaction.where(transactable_type: "Subscription", transactable_id: item_id).ids.map { |id| [ "CategoryTransaction", id ] },
      *EntityTransaction.where(transactable_type: "Subscription", transactable_id: item_id).ids.map { |id| [ "EntityTransaction", id ] }
    ]
  end

  def historical_dependent_identities
    transitions.filter_map do |candidate|
      next unless candidate.record_type.in?(DEPENDENT_TYPES)

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      [ candidate.record_type, candidate.item_id ] if states.any? { |state| belongs_to_subscription?(candidate.record_type, state) }
    end
  end

  def belongs_to_subscription?(dependent_type, state)
    if dependent_type.in?(%w[CategoryTransaction EntityTransaction])
      state.values_at("transactable_type", "transactable_id") == [ "Subscription", item_id ]
    else
      state["subscription_id"] == item_id
    end
  end
end
