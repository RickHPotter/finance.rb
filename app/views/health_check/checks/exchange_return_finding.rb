# frozen_string_literal: true

class Views::HealthCheck::Checks::ExchangeReturnFinding < Views::HealthCheck::Checks::FindingBase
  def view_template
    finding_shell(
      title: "##{row[:id]} · #{row[:description]}",
      subtitle: "#{formatted_date(row[:date])} · #{I18n.t("health_check.details.statuses.#{row[:paid] ? 'paid' : 'pending'}")}",
      href: cash_transaction_path(row[:id])
    ) do
      div(class: "space-y-4 p-4") do
        issue_chips(row[:issues])
        div(class: "grid gap-3 sm:grid-cols-2 lg:grid-cols-4") do
          metric(I18n.t("health_check.details.fields.recorded_total"), money(row[:price]))
          metric(I18n.t("health_check.details.fields.installments_total"), money(row[:installments_sum]))
          metric(I18n.t("health_check.details.fields.exchange_total"), money(row[:exchange_rows_sum]))
          metric(I18n.t("health_check.details.fields.allocation_findings"), Array(row[:source_allocation_rows]).size)
        end
        capability_reason
      end
    end
  end

  private

  def issue_translation_key(code)
    "health_check.details.issue_codes.exchange_return.#{code}"
  end
end
