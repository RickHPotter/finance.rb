# frozen_string_literal: true

class Audit::Rollback::Adapters::CashTransaction < Audit::Rollback::Adapters::Base
  SPECIAL_GRAPH_ATTRIBUTES = %w[
    cash_transaction_type friend_notification_intent investment_type_id reference_transactable_id
    reference_transactable_type subscription_id user_card_id
  ].freeze
  CARD_PAYMENT_PROJECTION_ATTRIBUTES = %w[cash_transaction_type user_card_id].freeze
  CARD_PAYMENT_PROJECTION_CHANGES = %w[comment price].freeze
  CARD_PAYMENT_INSTALLMENT_CHANGES = %w[price].freeze
  REFERENCE_DATE_SYNC_CHANGES = %w[date].freeze
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[cash_installments_count]).freeze
  CASH_RECALCULATIONS = %w[cash_installment_order cash_balance user_bank_account_totals].freeze

  def support_issues
    attributes = SPECIAL_GRAPH_ATTRIBUTES.select { |attribute| historical_state[attribute].present? }
    attributes -= CARD_PAYMENT_PROJECTION_ATTRIBUTES if supported_card_payment_graph?
    issues = attributes.present? ? [ issue(:unsupported_transaction_graph, attributes:) ] : []
    issues << issue(:incomplete_transaction_graph) if action == "recreate" && historical_installments.empty?
    issues
  end

  def dependencies
    return [] if current_record.nil?

    @dependencies ||= dependent_identities.map do |record_type, dependent_id|
      dependency(record_type:, item_id: dependent_id, relationship: :dependent)
    end.sort_by(&:key)
  end

  def recalculations
    CASH_RECALCULATIONS
  end

  def post_compensation_attributes
    return {} unless supported_card_payment_projection_update?

    { "description" => before_state["description"] }
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
    return false unless installment_transition.action == "update"
    return false unless installment_transition.net_changed_attributes.all? { |attribute| attribute.in?(CARD_PAYMENT_INSTALLMENT_CHANGES) }

    state = installment_transition.expected_after_state || installment_transition.before_state || {}
    card_transaction_transition = transitions.find do |candidate|
      candidate.record_type == "CardTransaction" && candidate.item_id == state["card_transaction_id"]
    end
    return false unless card_transaction_transition&.action == "update"

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
