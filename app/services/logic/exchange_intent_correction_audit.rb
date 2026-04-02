# frozen_string_literal: true

class Logic::ExchangeIntentCorrectionAudit
  attr_reader :rows, :source_transaction_ids

  def initialize(rows: nil, source_transaction_ids: nil)
    @rows = rows
    @source_transaction_ids = Array(source_transaction_ids).compact_blank.map(&:to_i)
  end

  def call
    {
      generated_at: Time.current.iso8601,
      candidate_count: candidates.size,
      candidates:
    }
  end

  private

  def candidates
    @candidates ||= filtered_rows.filter_map do |row|
      next unless reimbursement_retag_candidate?(row)

      {
        message_id: row.dig(:message, :id),
        conversation_id: row.dig(:message, :conversation_id),
        source_transaction_id: row.dig(:source, :id),
        current_intent: row[:intent],
        suggested_intent: "reimbursement",
        reason: "loan_chain_without_receiver_exchange_return",
        receiver_reference_transaction_id: row.dig(:end_transactions, 0, :id),
        receiver_exchange_return_transaction_id: row.dig(:end_transactions, 1, :id)
      }
    end
  end

  def filtered_rows
    return audit_rows if source_transaction_ids.empty?

    audit_rows.select { |row| source_transaction_ids.include?(row.dig(:source, :id)) }
  end

  def audit_rows
    @audit_rows ||= rows || Logic::ExchangeTrioAudit.new.call
  end

  def reimbursement_retag_candidate?(row)
    row[:end_kind] == "loan_receiver_combo" &&
      row.dig(:end_transactions, 1).blank?
  end
end
