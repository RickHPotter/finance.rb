# frozen_string_literal: true

class Views::HealthCheck::Checks::PiggyBankFinding < Views::HealthCheck::Checks::FindingBase
  def view_template
    finding_shell(
      title: row[:id] ? "##{row[:id]} · #{row[:description]}" : row[:description],
      subtitle: formatted_date(row[:date]),
      href: (cash_transaction_path(row[:id]) if row[:id])
    ) do
      div(class: "space-y-4 p-4") do
        issue_chips(row[:issues])
        div(class: "grid gap-3 sm:grid-cols-2 lg:grid-cols-4") do
          metric(I18n.t("health_check.details.fields.principal"), money(row[:principal]))
          metric(I18n.t("health_check.details.fields.valuation_delta"), money(row[:valuation_delta]))
          metric(I18n.t("health_check.details.fields.expected_total"), money(row[:expected_total]))
          metric(I18n.t("health_check.details.fields.recorded_total"), money(row[:recorded_total]))
        end
        capability_reason
      end
    end
  end

  private

  def issue_translation_key(code)
    "health_check.details.issue_codes.piggy_bank.#{code}"
  end
end
