# frozen_string_literal: true

class Logic::ExchangeChainReferenceAudit
  attr_reader :middle_overrides, :receiver_overrides, :rows, :source_transaction_ids

  def initialize(rows: nil, source_transaction_ids: nil, middle_overrides: nil, receiver_overrides: nil)
    @middle_overrides = middle_overrides
    @receiver_overrides = receiver_overrides
    @rows = rows
    @source_transaction_ids = Array(source_transaction_ids).compact_blank.map(&:to_i)
  end

  def call
    {
      generated_at: Time.current.iso8601,
      candidate_count: candidates.size,
      supported_count: candidates.count { |candidate| candidate[:supported] },
      skipped_count: candidates.count { |candidate| !candidate[:supported] },
      candidates:
    }
  end

  private

  def candidates
    @candidates ||= filtered_rows.filter_map do |row|
      next if row[:status] == "done"
      next if row[:proposed_changes].blank?

      unsupported_reason = unsupported_reason_for(row)

      {
        message_id: row.dig(:message, :id),
        conversation_id: row.dig(:message, :conversation_id),
        source_transaction_id: row.dig(:source, :id),
        chain_kind: row[:chain_kind],
        end_kind: row[:end_kind],
        intent: row[:intent],
        issues: row[:issues],
        proposed_changes: row[:proposed_changes],
        supported: unsupported_reason.blank?,
        unsupported_reason:
      }
    end
  end

  def filtered_rows
    return audit_rows if source_transaction_ids.empty?

    audit_rows.select { |row| source_transaction_ids.include?(row.dig(:source, :id)) }
  end

  def audit_rows
    @audit_rows ||= begin
      source_rows = rows || Logic::ExchangeTrioAudit.new.call
      Logic::ExchangeAuditSelectionProjector.new(rows: source_rows, middle_overrides:, receiver_overrides:).call
    end
  end

  def unsupported_reason_for(row)
    return "multiple_middle_candidates" if row[:issues].include?("multiple_middle_candidates")
    return "missing_middle" if row[:issues].include?("missing_middle")
    return "non_cash_transaction_target" unless row[:proposed_changes].all? { |change| change.dig(:transaction, :type) == "CashTransaction" }
    return "unsupported_reference_target_type" unless supported_reference_targets?(row[:proposed_changes])

    nil
  end

  def supported_reference_targets?(changes)
    changes.all? do |change|
      reference_type = change.dig(:to_reference, :type)
      reference_type.blank? || reference_type.in?(%w[CashTransaction CardTransaction])
    end
  end
end
