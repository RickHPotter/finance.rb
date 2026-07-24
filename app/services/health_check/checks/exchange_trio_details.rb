# frozen_string_literal: true

class HealthCheck::Checks::ExchangeTrioDetails < HealthCheck::Checks::DetailsBase
  ISSUE_CODES = %w[
    multiple_middle_candidates
    missing_middle
    missing_receiver_reference
    missing_receiver_exchange_return
    source_reference_missing
    source_reference_should_be_blank
    source_reference_mismatch
    middle_reference_missing
    middle_reference_should_be_blank
    middle_reference_mismatch
    middle_candidate_reference_missing
    middle_candidate_reference_should_be_blank
    middle_candidate_reference_mismatch
    receiver_shared_return_reference_missing
    receiver_shared_return_reference_should_be_blank
    receiver_shared_return_reference_mismatch
    receiver_exchange_reference_missing
    receiver_exchange_reference_should_be_blank
    receiver_exchange_reference_mismatch
    receiver_exchange_return_reference_missing
    receiver_exchange_return_reference_should_be_blank
    receiver_exchange_return_reference_mismatch
  ].freeze

  private

  def rows
    projected_rows.filter_map do |row|
      next if row[:status] == "done"
      next if selected_issue.present? && !Array(row[:issues]).include?(selected_issue)

      candidate = candidates_by_message_id[row.dig(:message, :id)]
      row.merge(
        health_check: {
          repairable: candidate&.fetch(:supported, false) || false,
          unavailable_reason: candidate&.dig(:unsupported_reason) || ("no_canonical_change" if row[:proposed_changes].blank?)
        }.compact
      )
    end
  end

  def projected_rows
    @projected_rows ||= begin
      audit_rows = Logic::ExchangeTrioAudit.new(
        current_user: scope.user,
        current_context: scope.context,
        connected_user_id: scope.connected_user&.id
      ).call
      Logic::ExchangeAuditSelectionProjector.new(rows: audit_rows).call
    end
  end

  def candidates_by_message_id
    @candidates_by_message_id ||= Logic::ExchangeChainReferenceAudit.new(rows: projected_rows).call[:candidates].index_by { |candidate| candidate[:message_id] }
  end

  def selected_issue
    @selected_issue ||= issue_filter(ISSUE_CODES)
  end

  def provider_filters
    { "issue_filter" => selected_issue }
  end

  def sort_key(row)
    [ sortable_time(row.dig(:message, :created_at)), row.dig(:message, :id).to_i, stable_id(row) ]
  end

  def stable_id(row)
    row.dig(:source, :id).to_i
  end
end
