# frozen_string_literal: true

class Logic::StandaloneExchangeParentReferenceRunner
  attr_reader :dry_run, :ids

  def initialize(ids: nil, dry_run: true)
    @ids = Array(ids).compact_blank.map(&:to_i)
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      updates:,
      skipped:,
      processed_count: target_transactions.size,
      updated_count: updates.size,
      skipped_count: skipped.size
    }
  end

  private

  def audit
    @audit ||= Logic::StandaloneExchangeParentReferenceAudit.new(ids:)
  end

  def candidates
    @candidates ||= audit.call.fetch(:candidates)
  end

  def candidates_by_id
    @candidates_by_id ||= candidates.index_by { |candidate| candidate[:exchange_return_transaction_id] }
  end

  def updates
    @updates ||= run_result[:updates]
  end

  def skipped
    @skipped ||= run_result[:skipped]
  end

  def run_result
    @run_result ||= run
  end

  def run
    target_transactions.each_with_object({ updates: [], skipped: [] }) do |transaction, result|
      process_transaction(transaction, result)
    end
  end

  def target_transactions
    return [] if candidates_by_id.empty?
    return @target_transactions if defined?(@target_transactions)

    @target_transactions = CashTransaction.includes(exchanges: { entity_transaction: :transactable })
                                          .where(id: candidates_by_id.keys)
                                          .order(:id)
                                          .select { |transaction| standalone_exchange_return_candidate?(transaction) }
  end

  def standalone_exchange_return_candidate?(transaction)
    transaction.exchanges.monetary.distinct.pluck(:bound_type) == [ "standalone" ]
  end

  def process_transaction(transaction, result)
    candidate = candidates_by_id[transaction.id]
    return skip_transaction(result, transaction.id, "candidate_not_found") if candidate.blank?
    return result[:skipped] << candidate.merge(reason: candidate[:unsupported_reason]) unless candidate[:supported]

    desired_reference = load_reference(candidate[:desired_reference])
    return result[:skipped] << candidate.merge(reason: "record_not_found") if desired_reference.blank?

    update_payload = serialize_update(transaction, desired_reference)
    return result[:updates] << update_payload if dry_run

    apply_update(transaction, desired_reference, candidate:, result:, update_payload:)
  end

  def apply_update(transaction, desired_reference, candidate:, result:, update_payload:)
    timestamp = Time.current

    transaction.with_lock do
      return result[:skipped] << candidate.merge(reason: "reference_already_present") if transaction.reference_transactable.present?

      transaction.update_columns(
        reference_transactable_type: desired_reference.class.name,
        reference_transactable_id: desired_reference.id,
        updated_at: timestamp
      )
    end

    result[:updates] << update_payload
  end

  def skip_transaction(result, transaction_id, reason)
    result[:skipped] << { exchange_return_transaction_id: transaction_id, reason: }
  end

  def load_reference(reference_payload)
    return if reference_payload.blank?

    case reference_payload[:type] || reference_payload["type"]
    when "CashTransaction"
      CashTransaction.find_by(id: reference_payload[:id] || reference_payload["id"])
    when "CardTransaction"
      CardTransaction.find_by(id: reference_payload[:id] || reference_payload["id"])
    end
  end

  def serialize_update(transaction, desired_reference)
    {
      exchange_return_transaction_id: transaction.id,
      current_reference: nil,
      desired_reference: {
        id: desired_reference.id,
        type: desired_reference.class.name,
        description: desired_reference.try(:description),
        user_id: desired_reference.try(:user_id)
      }.compact
    }
  end
end
