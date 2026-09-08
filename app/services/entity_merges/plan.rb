# frozen_string_literal: true

class EntityMerges::Plan
  HARD_CONFLICT_REASONS = %i[cross_context_allocation unowned_allocation unsupported_owner].freeze

  RowPlan = Data.define(:row, :status, :reason_code, :details) do
    def eligible?
      %i[transfer collapse].include?(status)
    end

    def conflict?
      status == :conflict
    end

    def outcome
      Data.define(:reason_code).new(reason_code:)
    end
  end

  attr_reader :actor, :context, :source, :destination, :mode, :outcome, :reason_code,
              :transfer_rows, :collapse_rows, :conflict_rows

  def initialize(actor:, context:, source:, destination:, mode:, outcome: :eligible, reason_code: nil, transfer_rows: [], collapse_rows: [], conflict_rows: [])
    @actor = actor
    @context = context
    @source = source
    @destination = destination
    @mode = mode&.to_sym
    @outcome = outcome.to_sym
    @reason_code = reason_code&.to_sym
    @transfer_rows = transfer_rows
    @collapse_rows = collapse_rows
    @conflict_rows = conflict_rows
  end

  def eligible_only_available?
    return false if outcome == :conflict
    return false if conflict_rows.any? { |row_plan| row_plan.reason_code.in?(HARD_CONFLICT_REASONS) }

    AllocationMutations::IndependenceClassifier.new(
      plans: row_plans,
      dependency_keys: ->(row_plan) { row_plan.details[:graph_keys] }
    ).eligible_only_available?
  end

  def apply_available?
    return false if outcome == :conflict

    if mode == :strict
      conflict_rows.empty?
    else
      eligible_only_available?
    end
  end

  def transaction_reassign_count
    transfer_rows.count { |rp| rp.row.is_a?(EntityTransaction) }
  end

  def transaction_dedup_count
    collapse_rows.count { |rp| rp.row.is_a?(EntityTransaction) }
  end

  def budget_reassign_count
    transfer_rows.count { |rp| rp.row.is_a?(BudgetEntity) }
  end

  def budget_dedup_count
    collapse_rows.count { |rp| rp.row.is_a?(BudgetEntity) }
  end

  def digest
    @digest ||= begin
      payload = {
        actor_id: actor.id,
        context_id: context&.id,
        source_id: source.id,
        destination_id: destination.id,
        mode: mode.to_s,
        outcome: outcome.to_s,
        reason_code: reason_code.to_s,
        source_state: master_state(source),
        destination_state: master_state(destination),
        rows: row_plans.map { |row_plan| row_fingerprint(row_plan) }.sort_by { |row| [ row[:record_type], row[:record_id] ] }
      }
      Digest::SHA256.hexdigest(AllocationMutations::Payload.canonical_json(payload))
    end
  end

  def row_plans
    @row_plans ||= transfer_rows + collapse_rows + conflict_rows
  end

  private

  def master_state(record)
    record.attributes.slice("id", "user_id", "active", "built_in", "friendship_id")
  end

  def row_fingerprint(row_plan)
    {
      record_type: row_plan.row.class.base_class.name,
      record_id: row_plan.row.id,
      status: row_plan.status.to_s,
      reason_code: row_plan.reason_code.to_s,
      details: row_plan.details
    }
  end
end
