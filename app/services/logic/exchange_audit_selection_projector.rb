# frozen_string_literal: true

class Logic::ExchangeAuditSelectionProjector
  attr_reader :middle_overrides, :receiver_overrides, :rows

  def initialize(rows:, middle_overrides: nil, receiver_overrides: nil)
    @rows = rows
    @middle_overrides = normalize_middle_overrides(middle_overrides)
    @receiver_overrides = normalize_receiver_overrides(receiver_overrides)
  end

  def call
    rows.map { |row| project_row(row) }
  end

  private

  def project_row(row)
    selected_middle = selected_middle_candidate_for(row)
    return row.merge(selected_middle_id: nil) if selected_middle.blank?

    projected_row = row.deep_dup
    projected_middle_candidates = project_middle_candidates(row, selected_middle)
    projected_receiver_candidates = project_receiver_candidates(row, selected_middle)
    selected_receiver = selected_receiver_candidate_for(row, projected_receiver_candidates)

    projected_row[:selected_middle_id] = selected_middle[:id]
    projected_row[:selected_receiver_id] = selected_receiver&.dig(:id)
    projected_row[:middle_candidates] = projected_middle_candidates
    projected_row[:middle] = projected_middle_candidates.find { |candidate| candidate[:id] == selected_middle[:id] }&.merge(node_key: "middle")
    projected_row[:receiver_candidates] = projected_receiver_candidates
    projected_row[:end_transactions] = projected_end_transactions(row, selected_middle, selected_receiver)
    projected_row[:issues] = projected_issues(projected_row)
    projected_row[:proposed_changes] = projected_proposed_changes(projected_row)
    projected_row[:status] = projected_row[:issues].empty? ? "done" : "pending"

    projected_row
  end

  def normalize_middle_overrides(overrides)
    return {} if overrides.blank?

    overrides.to_h.each_with_object({}) do |(source_id, middle_id), result|
      next if source_id.blank? || middle_id.blank?

      result[source_id.to_i] = middle_id.to_i
    end
  end

  def normalize_receiver_overrides(overrides)
    return {} if overrides.blank?

    overrides.to_h.each_with_object({}) do |(source_id, receiver_id), result|
      next if source_id.blank? || receiver_id.blank?

      result[source_id.to_i] = receiver_id.to_i
    end
  end

  def selected_middle_candidate_for(row)
    selected_middle_id = middle_overrides[row.dig(:source, :id)]
    return middle_candidates_for(row).find { |candidate| candidate[:id] == selected_middle_id } if selected_middle_id.present?

    inferred_middle_candidate_for(row) || row[:middle] || middle_candidates_for(row).first
  end

  def selected_receiver_candidate_for(row, receiver_candidates)
    selected_receiver_id = receiver_overrides[row.dig(:source, :id)]
    return if selected_receiver_id.blank?

    receiver_candidates.find { |candidate| candidate[:id] == selected_receiver_id }
  end

  def projected_end_transactions(row, selected_middle, selected_receiver)
    end_transactions = end_transactions_for(row)

    end_transactions.each_with_index.map do |transaction, index|
      transaction ||= selected_receiver if index.zero?
      next if transaction.blank?

      expected_reference =
        if index.zero?
          serialize_reference(selected_middle)
        elsif row[:end_kind] == "loan_receiver_combo"
          serialize_reference(end_transactions.first)
        else
          transaction[:expected_reference]
        end

      project_transaction(transaction, expected_reference:).merge(node_key: end_node_key_for(row, index))
    end
  end

  def project_receiver_candidates(row, selected_middle)
    expected_reference = serialize_reference(selected_middle)
    receiver_candidates = Array(row[:receiver_candidates]).select do |candidate|
      receiver_candidate_matches_middle?(candidate, selected_middle)
    end

    receiver_candidates.map do |candidate|
      project_transaction(candidate, expected_reference:).merge(node_key: "receiver_candidate")
    end
  end

  def project_middle_candidates(row, selected_middle)
    expected_reference = serialize_reference(row[:source])

    middle_candidates_for(row).map do |candidate|
      projected_candidate = project_transaction(candidate, expected_reference:)
      projected_candidate[:node_key] = selected_middle[:id] == candidate[:id] ? "middle" : "middle_candidate"
      projected_candidate
    end
  end

  def projected_proposed_changes(row)
    projected_transactions_for(row).filter_map do |transaction|
      next if transaction[:reference_status] == "ok"

      {
        node_key: transaction[:node_key],
        transaction: {
          id: transaction[:id],
          type: transaction[:type],
          description: transaction[:description],
          user_id: transaction[:user_id]
        },
        from_reference: transaction[:current_reference],
        to_reference: transaction[:expected_reference],
        action: transaction[:expected_reference].present? ? "set_reference" : "clear_reference"
      }
    end
  end

  def projected_issues(row)
    base_issues = [
      *reference_issues_for(row[:source]),
      *middle_issues_for(row),
      *receiver_issues_for(row)
    ]

    base_issues.uniq
  end

  def project_transaction(transaction, expected_reference:)
    projected_transaction = transaction.deep_dup
    projected_transaction[:expected_reference] = expected_reference
    projected_transaction[:reference_status] = reference_status_for(
      current_reference: projected_transaction[:current_reference],
      expected_reference:
    )
    projected_transaction
  end

  def serialize_reference(transaction)
    return if transaction.blank?

    {
      id: transaction[:id],
      type: transaction[:type],
      description: transaction[:description],
      user_id: transaction[:user_id]
    }.compact
  end

  def reference_status_for(current_reference:, expected_reference:)
    return "ok" if current_reference.blank? && expected_reference.blank?
    return "unexpected" if current_reference.present? && expected_reference.blank?
    return "missing" if current_reference.blank? && expected_reference.present?
    return "ok" if same_reference?(current_reference, expected_reference)

    "mismatch"
  end

  def same_reference?(left, right)
    left.present? &&
      right.present? &&
      left[:type] == right[:type] &&
      left[:id] == right[:id]
  end

  def reference_issues_for(node)
    return [] if node.blank?

    case node[:reference_status]
    when "ok"
      []
    when "missing"
      [ "#{node[:node_key]}_reference_missing" ]
    when "unexpected"
      [ "#{node[:node_key]}_reference_should_be_blank" ]
    else
      [ "#{node[:node_key]}_reference_mismatch" ]
    end
  end

  def projected_transactions_for(row)
    [ row[:source], row[:middle], *unselected_middle_candidates_for(row), *end_transactions_for(row) ].compact
  end

  def unselected_middle_candidates_for(row)
    middle_candidates_for(row).reject { |candidate| candidate[:id] == row.dig(:middle, :id) }
  end

  def middle_issues_for(row)
    issues = []
    issues << "missing_middle" if middle_candidates_for(row).empty?
    issues.concat(reference_issues_for(row[:middle]))
    issues.concat(unselected_middle_candidates_for(row).flat_map { |candidate| reference_issues_for(candidate) })
    issues
  end

  def receiver_issues_for(row)
    end_transactions = end_transactions_for(row)
    issues = []
    issues << "missing_receiver_reference" if end_transactions.first.blank?
    issues.concat(reference_issues_for(end_transactions.first))
    return issues unless row[:end_kind] == "loan_receiver_combo"

    issues << "missing_receiver_exchange_return" if end_transactions.second.blank?
    issues.concat(reference_issues_for(end_transactions.second))
    issues
  end

  def inferred_middle_candidate_for(row)
    receiver_id = row.dig(:receiver, :id)
    return if receiver_id.blank?

    matching_candidates = middle_candidates_for(row).select do |candidate|
      candidate.fetch(:entity_user_ids, []).include?(receiver_id)
    end

    matching_candidates.one? ? matching_candidates.first : nil
  end

  def middle_candidates_for(row)
    Array(row[:middle_candidates])
  end

  def end_transactions_for(row)
    Array(row[:end_transactions])
  end

  def receiver_candidate_matches_middle?(candidate, selected_middle)
    candidate[:price].to_i.abs == selected_middle[:price].to_i.abs &&
      Array(candidate[:installment_signature]) == Array(selected_middle[:installment_signature])
  end

  def end_node_key_for(row, index)
    return "receiver_exchange" if row[:end_kind] == "loan_receiver_combo" && index.zero?
    return "receiver_exchange_return" if row[:end_kind] == "loan_receiver_combo"

    "receiver_shared_return"
  end
end
