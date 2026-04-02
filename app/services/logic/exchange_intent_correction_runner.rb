# frozen_string_literal: true

class Logic::ExchangeIntentCorrectionRunner
  attr_reader :dry_run, :source_transaction_ids

  def initialize(source_transaction_ids: nil, dry_run: true)
    @source_transaction_ids = Array(source_transaction_ids).compact_blank.map(&:to_i)
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      candidate_count: candidates.size,
      updated_messages_count: updates.sum { |entry| entry[:message_ids].size },
      skipped_count: skipped.size,
      updates:,
      skipped:
    }
  end

  private

  def audit
    @audit ||= Logic::ExchangeIntentCorrectionAudit.new(source_transaction_ids:)
  end

  def candidates
    @candidates ||= audit.call.fetch(:candidates)
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
    candidates.each_with_object({ updates: [], skipped: [] }) do |candidate, result|
      messages = target_messages_for(candidate)

      if messages.blank?
        result[:skipped] << candidate.merge(reason: "messages_not_found")
        next
      end

      updated_headers = rewrite_headers(messages.first.headers)

      if updated_headers.blank?
        result[:skipped] << candidate.merge(reason: "invalid_headers")
        next
      end

      unless dry_run
        timestamp = Time.current
        messages.each do |message|
          message.update_columns(headers: JSON.generate(updated_headers), updated_at: timestamp)
        end
      end

      result[:updates] << candidate.merge(
        message_ids: messages.map(&:id),
        target_headers: updated_headers
      )
    end
  end

  def target_messages_for(candidate)
    source_transaction_id = candidate.fetch(:source_transaction_id)

    Message.joins(:conversation)
           .merge(Conversation.assistant)
           .where(reference_transactable_type: "CashTransaction", reference_transactable_id: source_transaction_id)
           .where(superseded_by_id: nil, body: %w[notification:create notification:update])
           .where(id: candidate.fetch(:message_id))
           .to_a
  end

  def rewrite_headers(headers)
    parsed_headers = JSON.parse(headers)
    replay = parsed_headers["replay"]
    return if replay.blank?

    parsed_headers.merge("replay" => replay.merge("intent" => "reimbursement"))
  rescue JSON::ParserError
    nil
  end
end
