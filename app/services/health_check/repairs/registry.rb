# frozen_string_literal: true

class HealthCheck::Repairs::Registry
  Definition = Data.define(:check_key, :key, :title_key, :planner) do
    def initialize(check_key:, key:, title_key:, planner:)
      entry = HealthCheck::Registry.fetch(check_key)
      raise ArgumentError, "repair is not declared by check" unless key.to_s.in?(entry.repair_keys)
      raise ArgumentError, "invalid planner" unless planner.respond_to?(:new)

      super(
        check_key: check_key.to_s,
        key: key.to_s,
        title_key: title_key.to_s,
        planner:
      )
    end
  end

  DEFINITIONS = [
    Definition.new(
      check_key: "exchange_trio",
      key: "canonical_reference",
      title_key: "health_check.repairs.canonical_reference.title",
      planner: HealthCheck::Repairs::CanonicalReferencePlanner
    ),
    Definition.new(
      check_key: "exchange_return",
      key: "source_allocation",
      title_key: "health_check.repairs.source_allocation.title",
      planner: HealthCheck::Repairs::ExchangeReturnAllocationPlanner
    ),
    Definition.new(
      check_key: "card_exchange_projection",
      key: "projection",
      title_key: "health_check.repairs.projection.title",
      planner: HealthCheck::Repairs::CardExchangeProjectionPlanner
    ),
    Definition.new(
      check_key: "misplaced_exchange_intent",
      key: "convert_to_reimbursement",
      title_key: "health_check.repairs.convert_to_reimbursement.title",
      planner: HealthCheck::Repairs::MisplacedExchangeIntentPlanner
    )
  ].freeze
  INDEX = DEFINITIONS.index_by { |definition| [ definition.check_key, definition.key ] }.freeze

  class << self
    def find(check_key, repair_key)
      INDEX[[ check_key.to_s, repair_key.to_s ]]
    end

    def fetch(check_key, repair_key)
      INDEX.fetch([ check_key.to_s, repair_key.to_s ])
    end

    def for_check(check_key)
      DEFINITIONS.select { |definition| definition.check_key == check_key.to_s }
    end
  end
end
