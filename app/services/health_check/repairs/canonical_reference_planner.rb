# frozen_string_literal: true

class HealthCheck::Repairs::CanonicalReferencePlanner < HealthCheck::Repairs::BasePlanner
  def call
    row = scoped_rows.find { |candidate| candidate.dig(:source, :id).to_i == finding_id }
    raise ActiveRecord::RecordNotFound if row.blank?

    candidate = reference_candidates.find { |entry| entry[:source_transaction_id].to_i == finding_id }
    unless candidate&.fetch(:supported, false)
      return read_only(
        candidate&.dig(:unsupported_reason) || "no_canonical_change",
        references: references_for(row, candidate)
      )
    end

    update = dry_run_update
    return read_only("finding_not_current", references: references_for(row, candidate)) if update.blank?

    previewable(
      changes: changes_for(update),
      references: references_for(row, candidate),
      warnings: Array(candidate[:issues])
    )
  end

  private

  def scoped_rows
    @scoped_rows ||= begin
      rows = Logic::ExchangeTrioAudit.new(
        current_user: scope.user,
        current_context: scope.context,
        connected_user_id: scope.connected_user&.id
      ).call
      Logic::ExchangeAuditSelectionProjector.new(rows:).call
    end
  end

  def reference_audit
    @reference_audit ||= Logic::ExchangeChainReferenceAudit.new(rows: scoped_rows, source_transaction_ids: [ finding_id ]).call
  end

  def reference_candidates
    reference_audit.fetch(:candidates)
  end

  def dry_run_update
    Logic::ExchangeChainReferenceRunner.new(
      rows: scoped_rows,
      source_transaction_ids: [ finding_id ],
      dry_run: true
    ).call.fetch(:updates).first
  end

  def changes_for(update)
    update.fetch(:applied_changes).map do |planned|
      transaction = planned.fetch(:transaction)
      change(
        record_type: transaction.fetch(:type),
        record_id: transaction.fetch(:id),
        attribute: "reference_transactable",
        before: planned[:from_reference],
        after: planned[:to_reference],
        metadata: {
          node_key: planned[:node_key],
          description: transaction[:description],
          user_id: transaction[:user_id]
        }
      )
    end
  end

  def references_for(row, candidate)
    [
      {
        type: row.dig(:source, :type),
        id: finding_id,
        role: "source",
        description: row.dig(:source, :description)
      },
      {
        type: "Message",
        id: candidate&.dig(:message_id) || row.dig(:message, :id),
        role: "conversation_message",
        conversation_id: candidate&.dig(:conversation_id) || row.dig(:message, :conversation_id)
      }
    ]
  end
end
