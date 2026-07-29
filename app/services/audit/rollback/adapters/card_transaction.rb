# frozen_string_literal: true

class Audit::Rollback::Adapters::CardTransaction < Audit::Rollback::Adapters::Base
  SPECIAL_GRAPH_ATTRIBUTES = %w[advance_cash_transaction_id reference_transactable_id reference_transactable_type subscription_id].freeze
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[card_installments_count]).freeze
  CARD_RECALCULATIONS = %w[card_installment_cycles cash_balance user_card_totals].freeze

  def support_issues
    attributes = SPECIAL_GRAPH_ATTRIBUTES.select { |attribute| historical_state[attribute].present? }
    attributes.delete("subscription_id") if supported_subscription_graph?
    attributes.delete("advance_cash_transaction_id") if supported_advance_graph?
    attributes -= %w[reference_transactable_id reference_transactable_type] if supported_reference_transaction_graph?
    issues = attributes.present? ? [ issue(:unsupported_transaction_graph, attributes:) ] : []
    issues << issue(:incomplete_transaction_graph) if action == "recreate" && historical_installments.empty?
    issues
  end

  def dependencies
    dependencies = dependent_identities.map do |record_type, dependent_id|
      dependency(record_type:, item_id: dependent_id, relationship: :dependent)
    end
    @dependencies = [ *dependencies, *subscription_dependencies, *special_parent_dependencies ].uniq(&:key).sort_by(&:key)
  end

  def recalculations
    CARD_RECALCULATIONS
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def historical_state
    expected_after_state || before_state || {}
  end

  def historical_installments
    transitions.select do |candidate|
      candidate.record_type == "CardInstallment" &&
        candidate.before_state&.fetch("card_transaction_id", nil) == item_id
    end
  end

  def supported_subscription_graph?
    subscription_transition.present?
  end

  def subscription_dependencies
    return [] unless subscription_transition

    [ dependency(record_type: "Subscription", item_id: subscription_transition.item_id, relationship: :parent) ]
  end

  def subscription_transition
    return @subscription_transition if defined?(@subscription_transition)

    subscription_id = historical_state["subscription_id"]
    @subscription_transition = transitions.find do |candidate|
      candidate.record_type == "Subscription" && candidate.item_id == subscription_id &&
        candidate.owner_id == owner_id && candidate.context_id == context_id
    end
  end

  def supported_advance_graph?
    advance_id = historical_state["advance_cash_transaction_id"]
    return false if advance_id.blank?

    CashTransaction.unscoped.exists?(id: advance_id) || transitions.any? do |candidate|
      candidate.record_type == "CashTransaction" && candidate.item_id == advance_id && candidate.before_state.present?
    end
  end

  def supported_reference_transaction_graph?
    reference_type, reference_id = historical_state.values_at("reference_transactable_type", "reference_transactable_id")
    return false unless reference_type.in?(%w[CashTransaction CardTransaction]) && reference_id.present?

    reference_type.constantize.unscoped.exists?(id: reference_id) || transitions.any? do |candidate|
      candidate.record_type == reference_type && candidate.item_id == reference_id && candidate.before_state.present?
    end
  end

  def special_parent_dependencies
    dependencies = []
    advance_id = historical_state["advance_cash_transaction_id"]
    dependencies << dependency(record_type: "CashTransaction", item_id: advance_id, relationship: :parent) if advance_id

    reference_type, reference_id = historical_state.values_at("reference_transactable_type", "reference_transactable_id")
    if reference_type.in?(%w[CashTransaction CardTransaction]) && reference_id
      dependencies << dependency(record_type: reference_type, item_id: reference_id, relationship: :parent)
    end
    dependencies
  end

  def paid_history?
    super || current_record&.paid_history? || false
  end

  def dependent_identities
    dependent_scopes.flat_map do |record_type, scope|
      scope.pluck(:id).map { |id| [ record_type, id ] }
    end.uniq
  end

  def dependent_scopes
    {
      "CardInstallment" => CardInstallment.unscoped.where(installment_type: "CardInstallment", card_transaction_id: item_id),
      "CategoryTransaction" => CategoryTransaction.where(transactable_type: "CardTransaction", transactable_id: item_id),
      "EntityTransaction" => EntityTransaction.where(transactable_type: "CardTransaction", transactable_id: item_id)
    }
  end
end
