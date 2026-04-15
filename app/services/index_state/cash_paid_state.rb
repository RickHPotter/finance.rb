# frozen_string_literal: true

module IndexState
  module CashPaidState
    DEFAULT_PAID_STATE = "all"
    VALID_PAID_STATES = %w[all paid pending].freeze

    def resolve_paid_state(paid_state:, paid:, pending:)
      resolved_paid_state = paid_state.presence_in(VALID_PAID_STATES)
      return resolved_paid_state if resolved_paid_state.present?

      paid_value = paid.nil? || ActiveModel::Type::Boolean.new.cast(paid)
      pending_value = pending.nil? || ActiveModel::Type::Boolean.new.cast(pending)

      return "paid" if paid_value && !pending_value
      return "pending" if !paid_value && pending_value

      DEFAULT_PAID_STATE
    end

    def resolve_paid_filters(paid_state:, paid:, pending:)
      resolved_paid_state = resolve_paid_state(paid_state:, paid:, pending:)

      case resolved_paid_state
      when "paid"
        { paid: true, pending: false, paid_state: resolved_paid_state }
      when "pending"
        { paid: false, pending: true, paid_state: resolved_paid_state }
      else
        { paid: true, pending: true, paid_state: DEFAULT_PAID_STATE }
      end
    end
  end
end
