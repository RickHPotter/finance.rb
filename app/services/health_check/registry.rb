# frozen_string_literal: true

class HealthCheck::Registry
  Entry = Data.define(:key, :group, :title_key, :description_key, :severity, :scope_kind, :runner, :details, :repair_keys) do
    def initialize(**attributes)
      attributes.assert_valid_keys(:key, :group, :title_key, :description_key, :severity, :scope_kind, :runner, :details, :repair_keys)

      key = attributes.fetch(:key)
      group = attributes.fetch(:group)
      title_key = attributes.fetch(:title_key)
      description_key = attributes.fetch(:description_key)
      severity = attributes.fetch(:severity)
      scope_kind = attributes.fetch(:scope_kind)
      runner = attributes.fetch(:runner)
      details = attributes.fetch(:details)
      repair_keys = attributes.fetch(:repair_keys, [])

      validate_value!(:key, key, HealthCheck::Vocabulary::CHECK_KEYS)
      validate_value!(:group, group, HealthCheck::Vocabulary::GROUPS)
      validate_value!(:severity, severity, HealthCheck::Vocabulary::SEVERITIES)
      validate_value!(:scope_kind, scope_kind, HealthCheck::Vocabulary::SCOPE_KINDS)
      raise ArgumentError, "invalid runner" unless runner.respond_to?(:new)
      raise ArgumentError, "invalid details" unless details.respond_to?(:new)

      super(
        key: key.to_s,
        group: group.to_s,
        title_key: title_key.to_s,
        description_key: description_key.to_s,
        severity: severity.to_s,
        scope_kind: scope_kind.to_s,
        runner:,
        details:,
        repair_keys: Array(repair_keys).map(&:to_s).uniq.freeze
      )
    end

    def connection_scoped?
      scope_kind == "context_with_connections"
    end

    def repairable?
      repair_keys.any?
    end

    private

    def validate_value!(attribute, value, allowed)
      raise ArgumentError, "invalid #{attribute}" unless value.to_s.in?(allowed)
    end
  end

  PENDING_ADAPTER = HealthCheck::Checks::Pending
  ENTRY_LIST = [
    Entry.new(
      key: "exchange_trio",
      group: "financial_integrity",
      title_key: "health_check.checks.exchange_trio.title",
      description_key: "health_check.checks.exchange_trio.description",
      severity: "error",
      scope_kind: "context_with_connections",
      runner: HealthCheck::Checks::ExchangeTrio,
      details: PENDING_ADAPTER,
      repair_keys: %w[canonical_reference]
    ),
    Entry.new(
      key: "exchange_return",
      group: "financial_integrity",
      title_key: "health_check.checks.exchange_return.title",
      description_key: "health_check.checks.exchange_return.description",
      severity: "error",
      scope_kind: "context",
      runner: HealthCheck::Checks::ExchangeReturn,
      details: PENDING_ADAPTER,
      repair_keys: %w[source_allocation]
    ),
    Entry.new(
      key: "card_exchange_projection",
      group: "financial_integrity",
      title_key: "health_check.checks.card_exchange_projection.title",
      description_key: "health_check.checks.card_exchange_projection.description",
      severity: "error",
      scope_kind: "context",
      runner: HealthCheck::Checks::CardExchangeProjection,
      details: PENDING_ADAPTER,
      repair_keys: %w[projection]
    ),
    Entry.new(
      key: "misplaced_exchange_intent",
      group: "financial_integrity",
      title_key: "health_check.checks.misplaced_exchange_intent.title",
      description_key: "health_check.checks.misplaced_exchange_intent.description",
      severity: "error",
      scope_kind: "context_with_connections",
      runner: HealthCheck::Checks::MisplacedExchangeIntent,
      details: PENDING_ADAPTER,
      repair_keys: %w[convert_to_reimbursement]
    ),
    Entry.new(
      key: "piggy_bank",
      group: "financial_integrity",
      title_key: "health_check.checks.piggy_bank.title",
      description_key: "health_check.checks.piggy_bank.description",
      severity: "error",
      scope_kind: "context",
      runner: HealthCheck::Checks::PiggyBank,
      details: PENDING_ADAPTER
    )
  ].freeze
  ENTRIES = ENTRY_LIST.index_by(&:key).freeze
  KEYS = ENTRIES.keys.freeze

  class << self
    def entries
      ENTRY_LIST
    end

    def keys
      KEYS
    end

    def find(key)
      ENTRIES[key.to_s]
    end

    def fetch(key)
      ENTRIES.fetch(key.to_s)
    end
  end
end
