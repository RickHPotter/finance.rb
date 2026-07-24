# frozen_string_literal: true

class HealthCheck::Checks::PiggyBankDetails < HealthCheck::Checks::DetailsBase
  ISSUE_CODES = %w[
    wrong_category
    missing_contributions
    user_context_mismatch
    entity_mismatch
    duplicate_contribution_ownership
    incompatible_sources
    grouped_principal_drift
    valuation_profit_drift
    source_return_amount_drift
    illegal_installment_collapse
    missing_return
  ].freeze

  private

  def rows
    audit_rows.filter_map do |row|
      next if selected_issue.present? && !Array(row[:issues]).include?(selected_issue)

      row.merge(health_check: { repairable: false, unavailable_reason: "diagnostic_only" })
    end
  end

  def selected_issue
    @selected_issue ||= issue_filter(ISSUE_CODES)
  end

  def audit_rows
    @audit_rows ||= Logic::PiggyBankAudit.new(current_user: scope.user, current_context: scope.context).call
  end

  def stable_id(row)
    (row[:id] || row[:piggy_bank_id]).to_i
  end

  def provider_filters
    { "issue_filter" => selected_issue }
  end
end
