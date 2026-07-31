# frozen_string_literal: true

class EntityMerges::Plan
  RowPlan = Data.define(:row, :status, :reason_code) do
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

  attr_reader :actor, :source, :destination, :mode, :outcome, :reason_code,
              :transfer_rows, :collapse_rows, :conflict_rows

  def initialize(actor:, source:, destination:, mode:, outcome: :eligible, reason_code: nil, transfer_rows: [], collapse_rows: [], conflict_rows: [])
    @actor = actor
    @source = source
    @destination = destination
    @mode = mode.to_sym
    @outcome = outcome.to_sym
    @reason_code = reason_code&.to_sym
    @transfer_rows = transfer_rows
    @collapse_rows = collapse_rows
    @conflict_rows = conflict_rows
  end

  def eligible_only_available?
    return false if outcome == :conflict

    AllocationMutations::IndependenceClassifier.new(plans: row_plans).eligible_only_available?
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
        source_id: source.id,
        destination_id: destination.id,
        mode: mode.to_s,
        outcome: outcome.to_s,
        reason_code: reason_code.to_s,
        transfer_count: transfer_rows.size,
        collapse_count: collapse_rows.size,
        conflict_count: conflict_rows.size,
        conflict_reasons: conflict_rows.map(&:reason_code).sort
      }
      Digest::SHA256.hexdigest(AllocationMutations::Payload.canonical_json(payload))
    end
  end

  def row_plans
    @row_plans ||= transfer_rows + collapse_rows + conflict_rows
  end
end
