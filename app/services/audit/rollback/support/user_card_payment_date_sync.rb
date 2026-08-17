# frozen_string_literal: true

class Audit::Rollback::Support::UserCardPaymentDateSync
  PAYMENT_DATE_CHANGES = %w[days_until_due_date due_date_day].freeze
  DATE_CHANGE = %w[date].freeze

  attr_reader :transition, :transitions

  def initialize(transition:, transitions:)
    @transition = transition
    @transitions = transitions
  end

  def supported?
    return false unless invoice_transition_supported?
    return false unless cash_installment_transition_supported?

    user_card_transition = matching_user_card_transition
    return false unless user_card_transition

    matching_reference_pair?(user_card_transition)
  end

  private

  delegate :before_state, :context_id, :expected_after_state, :owner_id, to: :transition

  def invoice_transition_supported?
    historical_state = expected_after_state || before_state || {}
    transition.action == "update" &&
      historical_state["cash_transaction_type"] == "CardInstallment" &&
      historical_state["user_card_id"].present? &&
      transition.net_changed_attributes == DATE_CHANGE
  end

  def cash_installment_transition_supported?
    candidates = transitions.select do |candidate|
      state = candidate.expected_after_state || candidate.before_state || {}
      candidate.record_type == "CashInstallment" &&
        candidate.action == "update" &&
        state["cash_transaction_id"] == transition.item_id
    end
    return false unless candidates.one?

    candidate = candidates.sole
    candidate.owner_id == owner_id &&
      candidate.context_id == context_id &&
      candidate.net_changed_attributes == DATE_CHANGE &&
      same_local_date?(candidate.before_state, before_state) &&
      same_local_date?(candidate.expected_after_state, expected_after_state)
  end

  def matching_user_card_transition
    candidates = transitions.select do |candidate|
      candidate.record_type == "UserCard" &&
        candidate.item_id == user_card_id &&
        candidate.action == "update" &&
        candidate.owner_id == owner_id &&
        candidate.net_changed_attributes.present? &&
        candidate.net_changed_attributes.all? { |attribute| attribute.in?(PAYMENT_DATE_CHANGES) }
    end
    candidates.sole if candidates.one?
  end

  def matching_reference_pair?(user_card_transition)
    candidates = matching_reference_transitions
    return false unless candidates.map(&:action).sort == %w[destroy recreate]

    references = reference_states_by_action(candidates)
    payment_dates_match?(before_state, references["recreate"], user_card_transition.before_state) &&
      payment_dates_match?(expected_after_state, references["destroy"], user_card_transition.expected_after_state, validate_closing_offset: true)
  end

  def matching_reference_transitions
    transitions.select do |candidate|
      next false unless candidate.record_type == "Reference"

      state = candidate.before_state || candidate.expected_after_state || {}
      state.values_at("user_card_id", "month", "year") == invoice_key &&
        candidate.owner_id == owner_id && candidate.context_id == context_id
    end
  end

  def reference_states_by_action(candidates)
    candidates.to_h do |candidate|
      state = candidate.action == "recreate" ? candidate.before_state : candidate.expected_after_state
      [ candidate.action, state ]
    end
  end

  def payment_dates_match?(transaction_state, reference_state, user_card_state, validate_closing_offset: false)
    transaction_date = Time.zone.parse(transaction_state.fetch("date")).to_date
    reference_date = Date.iso8601(reference_state.fetch("reference_date"))
    closing_date = Date.iso8601(reference_state.fetch("reference_closing_date"))

    return false unless transaction_date == reference_date
    return false unless reference_date.day == user_card_state.fetch("due_date_day")
    return false unless closing_date < reference_date

    !validate_closing_offset || (reference_date - closing_date).to_i == user_card_state.fetch("days_until_due_date")
  rescue ArgumentError, KeyError, NoMethodError
    false
  end

  def same_local_date?(first_state, second_state)
    Time.zone.parse(first_state.fetch("date")).to_date == Time.zone.parse(second_state.fetch("date")).to_date
  rescue ArgumentError, KeyError, NoMethodError
    false
  end

  def historical_state
    expected_after_state || before_state || {}
  end

  def user_card_id
    historical_state["user_card_id"]
  end

  def invoice_key
    historical_state.values_at("user_card_id", "month", "year")
  end
end
