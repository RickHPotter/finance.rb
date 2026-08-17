# frozen_string_literal: true

class Audit::Rollback::Adapters::CashTransaction < Audit::Rollback::Adapters::Base
  SPECIAL_GRAPH_ATTRIBUTES = %w[
    cash_transaction_type friend_notification_intent investment_type_id reference_transactable_id
    reference_transactable_type subscription_id user_card_id
  ].freeze
  CARD_PAYMENT_PROJECTION_ATTRIBUTES = %w[cash_transaction_type user_card_id].freeze
  CARD_PAYMENT_PROJECTION_CHANGES = %w[comment description price].freeze
  CARD_PAYMENT_INSTALLMENT_CHANGES = %w[price starting_price].freeze
  REFERENCE_DATE_SYNC_CHANGES = %w[date].freeze
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[cash_installments_count]).freeze
  CASH_RECALCULATIONS = %w[cash_installment_order cash_balance user_bank_account_totals].freeze

  def support_issues
    attributes = SPECIAL_GRAPH_ATTRIBUTES.select { |attribute| historical_state[attribute].present? }
    attributes -= CARD_PAYMENT_PROJECTION_ATTRIBUTES if supported_card_payment_graph?
    attributes.delete("subscription_id") if supported_subscription_graph?
    attributes -= %w[cash_transaction_type investment_type_id] if supported_investment_graph?
    attributes -= %w[cash_transaction_type reference_transactable_id reference_transactable_type] if supported_investment_valuation_graph?
    attributes -= %w[cash_transaction_type reference_transactable_id reference_transactable_type user_card_id] if supported_exchange_graph?
    attributes -= %w[cash_transaction_type reference_transactable_id reference_transactable_type] if supported_piggy_bank_graph?
    attributes.delete("friend_notification_intent") if supported_friend_notification_intent?
    attributes -= %w[reference_transactable_id reference_transactable_type] if supported_reference_transaction_graph? || orphaned_actionable_reference_recreation?
    attributes -= %w[cash_transaction_type user_card_id] if supported_card_advance_graph?
    issues = attributes.present? ? [ issue(:unsupported_transaction_graph, attributes:) ] : []
    issues << issue(:incomplete_transaction_graph) if action == "recreate" && historical_installments.empty?
    issues
  end

  def dependencies
    dependencies = dependent_identities.map do |record_type, dependent_id|
      dependency(record_type:, item_id: dependent_id, relationship: :dependent)
    end
    @dependencies = [ *dependencies, *subscription_dependencies, *reference_dependencies ].uniq(&:key).sort_by(&:key)
  end

  def recalculations
    CASH_RECALCULATIONS
  end

  def post_compensation_attributes
    return {} unless supported_card_payment_projection_update?

    before_state.slice("description", "comment")
  end

  def rollback_ignored_attributes
    attributes = super
    return attributes unless orphaned_actionable_reference_recreation?

    attributes + %w[reference_transactable_id reference_transactable_type]
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
      candidate.record_type == "CashInstallment" &&
        candidate.before_state&.fetch("cash_transaction_id", nil) == item_id
    end
  end

  def supported_subscription_graph?
    subscription_transition.present?
  end

  def supported_investment_graph?
    return false unless historical_state["cash_transaction_type"] == "Investment"

    transitions.any? do |candidate|
      next false unless candidate.record_type == "Investment"

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      candidate.owner_id == owner_id && candidate.context_id == context_id &&
        states.any? { |state| state["cash_transaction_id"] == item_id }
    end
  end

  def supported_investment_valuation_graph?
    return false unless historical_state["cash_transaction_type"] == "PiggyBank"
    return false unless transition.net_changed_attributes.all? { |attribute| attribute.in?(%w[paid price starting_price]) }

    transitions.any? do |candidate|
      next false unless candidate.record_type == "Investment"

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      candidate.owner_id == owner_id && candidate.context_id == context_id &&
        states.any? { |state| state["piggy_bank_return_cash_transaction_id"] == item_id }
    end
  end

  def supported_exchange_graph?
    return false unless historical_state["cash_transaction_type"] == "Exchange"

    transitions.any? do |candidate|
      next false unless candidate.record_type == "Exchange"

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      candidate.owner_id == owner_id && candidate.context_id == context_id &&
        states.any? { |state| state["cash_transaction_id"] == item_id }
    end
  end

  def supported_piggy_bank_graph?
    return false unless historical_state["cash_transaction_type"] == "PiggyBank"

    transitions.any? do |candidate|
      next false unless candidate.record_type == "PiggyBank"

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      candidate.owner_id == owner_id && candidate.context_id == context_id &&
        states.any? { |state| state["return_cash_transaction_id"] == item_id }
    end
  end

  def supported_friend_notification_intent?
    historical_state["friend_notification_intent"].in?(CashTransaction::FRIEND_NOTIFICATION_INTENTS)
  end

  def supported_reference_transaction_graph?
    reference_type, reference_id = historical_state.values_at("reference_transactable_type", "reference_transactable_id")
    return false unless reference_type.in?(%w[CashTransaction CardTransaction]) && reference_id.present?

    reference_type.constantize.unscoped.exists?(id: reference_id) || transitions.any? do |candidate|
      candidate.record_type == reference_type && candidate.item_id == reference_id && candidate.before_state.present?
    end
  end

  def supported_card_advance_graph?
    return false unless historical_state["cash_transaction_type"] == "CardTransaction" && historical_state["user_card_id"].present?

    transitions.any? do |candidate|
      next false unless candidate.record_type == "CardTransaction"

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      states.any? { |state| state["advance_cash_transaction_id"] == item_id }
    end
  end

  def reference_dependencies
    reference_type, reference_id = historical_state.values_at("reference_transactable_type", "reference_transactable_id")
    return [] unless reference_type.in?(%w[CashTransaction CardTransaction]) && reference_id.present?
    return [] if orphaned_actionable_reference_recreation?

    [ dependency(record_type: reference_type, item_id: reference_id, relationship: :parent) ]
  end

  def orphaned_actionable_reference_recreation?
    return false unless action == "recreate"
    return false unless transition.versions.all? { |version| version.operation.source_actionable_message? }

    reference_type, reference_id = historical_state.values_at("reference_transactable_type", "reference_transactable_id")
    return false unless reference_type.in?(%w[CashTransaction CardTransaction]) && reference_id.present?

    !reference_type.constantize.unscoped.exists?(id: reference_id) && transitions.none? do |candidate|
      candidate.record_type == reference_type && candidate.item_id == reference_id && candidate.before_state.present?
    end
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

  def supported_card_payment_projection_update?
    return false unless action == "update"
    return false unless historical_state["cash_transaction_type"] == "CardInstallment"
    return false if historical_state["user_card_id"].blank?
    return false unless transition.net_changed_attributes.all? { |attribute| attribute.in?(CARD_PAYMENT_PROJECTION_CHANGES) }
    return false unless projection_cash_installment_transition_supported?

    projection_card_installment_transitions.any? do |installment_transition|
      card_payment_installment_transition_supported?(installment_transition)
    end
  end

  def supported_card_payment_graph?
    supported_card_payment_projection_update? || supported_reference_date_sync? || supported_reference_merge_graph?
  end

  def supported_reference_merge_graph?
    return false unless historical_state["cash_transaction_type"] == "CardInstallment"
    return false if historical_state["user_card_id"].blank?
    return false unless reference_merge_transitions_supported?

    case action
    when "recreate" then historical_installments.present?
    when "update" then transition.net_changed_attributes.all? { |attribute| attribute.in?(CARD_PAYMENT_PROJECTION_CHANGES) }
    else false
    end
  end

  def reference_merge_transitions_supported?
    reference_transitions = transitions.select { |candidate| candidate.record_type == "Reference" }
    return false unless reference_transitions.map(&:action).sort == %w[recreate update]

    states = reference_transitions.map { |candidate| candidate.before_state || candidate.expected_after_state || {} }
    return false unless states.map { |state| state["user_card_id"] }.uniq == [ historical_state["user_card_id"] ]
    return false unless reference_transitions.map(&:context_id).uniq == [ context_id ]

    dates = states.map { |state| Date.new(state["year"], state["month"], 1) }.sort
    dates.first.next_month == dates.last
  rescue Date::Error, TypeError
    false
  end

  def supported_reference_date_sync?
    return false unless action == "update"
    return false unless historical_state["cash_transaction_type"] == "CardInstallment"
    return false if historical_state["user_card_id"].blank?
    return false unless transition.net_changed_attributes.all? { |attribute| attribute.in?(REFERENCE_DATE_SYNC_CHANGES) }
    return false unless projection_cash_installment_date_transition_supported?

    transitions.any? { |candidate| reference_date_transition_supported?(candidate) }
  end

  def projection_cash_installment_transition_supported?
    transitions.any? do |candidate|
      candidate.record_type == "CashInstallment" &&
        candidate.action == "update" &&
        transaction_id(candidate) == item_id &&
        candidate.net_changed_attributes.all? { |attribute| attribute.in?(CARD_PAYMENT_INSTALLMENT_CHANGES) }
    end
  end

  def projection_cash_installment_date_transition_supported?
    transitions.any? do |candidate|
      candidate.record_type == "CashInstallment" &&
        candidate.action == "update" &&
        transaction_id(candidate) == item_id &&
        candidate.net_changed_attributes.all? { |attribute| attribute.in?(REFERENCE_DATE_SYNC_CHANGES) }
    end
  end

  def reference_date_transition_supported?(candidate)
    return false unless candidate.record_type == "Reference" && candidate.action == "update"

    state = candidate.expected_after_state || candidate.before_state || {}
    state.values_at("user_card_id", "month", "year") ==
      historical_state.values_at("user_card_id", "month", "year") &&
      candidate.context_id == context_id
  end

  def projection_card_installment_transitions
    transitions.select do |candidate|
      candidate.record_type == "CardInstallment" && transaction_id(candidate) == item_id
    end
  end

  def card_payment_installment_transition_supported?(installment_transition)
    return false unless installment_transition.action.in?(%w[destroy recreate update])
    return false unless installment_transition.net_changed_attributes.all? { |attribute| attribute.in?(CARD_PAYMENT_INSTALLMENT_CHANGES) }
    return false unless installment_transition.owner_id == owner_id && installment_transition.context_id == context_id

    state = installment_transition.expected_after_state || installment_transition.before_state || {}
    matching_card_payment_parent?(installment_transition, state["card_transaction_id"])
  end

  def matching_card_payment_parent?(installment_transition, card_transaction_id)
    card_transaction_transition = transitions.find do |candidate|
      candidate.record_type == "CardTransaction" && candidate.item_id == card_transaction_id
    end
    return false unless card_transaction_transition&.action == installment_transition.action
    return false unless card_transaction_transition.owner_id == owner_id && card_transaction_transition.context_id == context_id

    card_transaction_state = card_transaction_transition.expected_after_state || card_transaction_transition.before_state || {}
    card_transaction_state["user_card_id"] == historical_state["user_card_id"]
  end

  def transaction_id(candidate)
    state = candidate.expected_after_state || candidate.before_state || {}
    state["cash_transaction_id"]
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
      "CashInstallment" => CashInstallment.unscoped.where(installment_type: "CashInstallment", cash_transaction_id: item_id),
      "CardInstallment" => CardInstallment.unscoped.where(installment_type: "CardInstallment", cash_transaction_id: item_id),
      "CategoryTransaction" => CategoryTransaction.where(transactable_type: "CashTransaction", transactable_id: item_id),
      "EntityTransaction" => EntityTransaction.where(transactable_type: "CashTransaction", transactable_id: item_id),
      "Exchange" => Exchange.where(cash_transaction_id: item_id),
      "Investment" => Investment.where(cash_transaction_id: item_id).or(Investment.where(piggy_bank_return_cash_transaction_id: item_id)),
      "PiggyBank" => PiggyBank.where(source_cash_transaction_id: item_id).or(PiggyBank.where(return_cash_transaction_id: item_id)),
      "CardTransaction" => CardTransaction.where(advance_cash_transaction_id: item_id)
    }
  end
end
