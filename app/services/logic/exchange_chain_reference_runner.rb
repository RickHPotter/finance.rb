# frozen_string_literal: true

class Logic::ExchangeChainReferenceRunner
  attr_reader :dry_run, :middle_overrides, :receiver_overrides, :rows, :source_transaction_ids

  def initialize(source_transaction_ids: nil, dry_run: true, middle_overrides: nil, receiver_overrides: nil, rows: nil)
    @source_transaction_ids = Array(source_transaction_ids).compact_blank.map(&:to_i)
    @dry_run = dry_run
    @middle_overrides = middle_overrides
    @receiver_overrides = receiver_overrides
    @rows = rows
  end

  def call
    Audit::Operation.with_mutation_source(:reference_sync) { result }
  end

  private

  def result
    {
      dry_run:,
      candidate_count: candidates.size,
      supported_count: supported_candidates.size,
      updated_row_count: updates.size,
      updated_change_count: updates.sum { |update| update[:applied_changes].size },
      skipped_count: skipped.size,
      updates:,
      skipped:
    }
  end

  def audit
    @audit ||= Logic::ExchangeChainReferenceAudit.new(rows:, source_transaction_ids:, middle_overrides:, receiver_overrides:)
  end

  def candidates
    @candidates ||= audit.call.fetch(:candidates)
  end

  def supported_candidates
    @supported_candidates ||= candidates.select { |candidate| candidate[:supported] }
  end

  def updates
    @updates ||= run_result[:updates]
  end

  def skipped
    @skipped ||= unsupported_candidates + run_result[:skipped]
  end

  def unsupported_candidates
    @unsupported_candidates ||= candidates.reject { |candidate| candidate[:supported] }.map do |candidate|
      candidate.slice(:message_id, :conversation_id, :source_transaction_id, :chain_kind, :end_kind, :intent, :issues).merge(
        reason: candidate[:unsupported_reason]
      )
    end
  end

  def run_result
    @run_result ||= run
  end

  def run
    supported_candidates.each_with_object({ updates: [], skipped: [] }) do |candidate, result|
      planned_changes = build_planned_changes(candidate)

      if planned_changes.blank?
        result[:skipped] << candidate.slice(:message_id, :conversation_id, :source_transaction_id, :chain_kind, :end_kind, :intent, :issues).merge(
          reason: "planned_changes_not_resolvable"
        )
        next
      end

      if dry_run
        result[:updates] << serialize_update(candidate, planned_changes)
        next
      end

      apply_planned_changes!(planned_changes)
      result[:updates] << serialize_update(candidate, planned_changes)
    rescue ActiveRecord::RecordNotUnique
      result[:skipped] << candidate.slice(:message_id, :conversation_id, :source_transaction_id, :chain_kind, :end_kind, :intent, :issues).merge(
        reason: "reference_uniqueness_conflict"
      )
    end
  end

  def build_planned_changes(candidate)
    planned_changes = candidate.fetch(:proposed_changes).filter_map do |change|
      build_planned_change(change)
    end

    return if planned_changes.size != candidate.fetch(:proposed_changes).size

    planned_changes.presence
  end

  def build_planned_change(change)
    transaction = load_cash_transaction(change.dig(:transaction, :id))
    return if transaction.blank?
    return unless references_match?(serialize_reference(transaction.reference_transactable), change[:from_reference])

    target_reference = load_reference(change[:to_reference])
    return if change[:to_reference].present? && target_reference.blank?

    {
      node_key: change[:node_key],
      transaction:,
      from_reference: change[:from_reference],
      to_reference: change[:to_reference],
      target_reference:
    }
  end

  def apply_planned_changes!(planned_changes)
    timestamp = Time.current

    ApplicationRecord.transaction do
      ordered_changes = planned_changes.sort_by { |change| [ apply_order_for(change[:node_key]), change[:transaction].id ] }
      ordered_changes.each do |change|
        change[:transaction].lock!
        transaction = change[:transaction]

        Audit::BulkMutation.update_columns!(transaction,
                                            reference_transactable_type: change[:target_reference]&.class&.name,
                                            reference_transactable_id: change[:target_reference]&.id,
                                            updated_at: timestamp)
      end
    end
  end

  def apply_order_for(node_key)
    {
      "receiver_exchange_return" => 0,
      "receiver_exchange" => 1,
      "receiver_shared_return" => 1,
      "middle" => 2,
      "middle_candidate" => 2,
      "source" => 3
    }.fetch(node_key.to_s, 9)
  end

  def load_cash_transaction(id)
    CashTransaction.find_by(id:)
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

  def serialize_reference(reference)
    return if reference.blank?

    {
      id: reference.id,
      type: reference.class.name
    }
  end

  def references_match?(current_reference, expected_reference)
    return true if current_reference.blank? && expected_reference.blank?
    return false if current_reference.blank? || expected_reference.blank?

    current_reference[:type] == (expected_reference[:type] || expected_reference["type"]) &&
      current_reference[:id] == (expected_reference[:id] || expected_reference["id"])
  end

  def serialize_update(candidate, planned_changes)
    candidate.slice(:message_id, :conversation_id, :source_transaction_id, :chain_kind, :end_kind, :intent, :issues).merge(
      applied_changes: planned_changes.map do |change|
        {
          node_key: change[:node_key],
          transaction: {
            id: change[:transaction].id,
            type: change[:transaction].class.name,
            description: change[:transaction].description,
            user_id: change[:transaction].user_id
          },
          from_reference: change[:from_reference],
          to_reference: change[:to_reference]
        }
      end
    )
  end
end
