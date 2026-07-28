# frozen_string_literal: true

module HealthCheck::Vocabulary
  CHECK_KEYS = %w[exchange_trio exchange_return card_exchange_projection misplaced_exchange_intent piggy_bank].freeze
  COUNT_KEYS = %w[affected failures warnings repairable read_only unavailable_actions].freeze
  EXECUTION_STATES = %w[queued running completed unavailable].freeze
  GROUPS = %w[financial_integrity].freeze
  OUTCOMES = %w[healthy warning failing].freeze
  SCOPE_KINDS = %w[context context_with_connections].freeze
  SEVERITIES = %w[error warning information].freeze
end
