# frozen_string_literal: true

class Views::HealthCheck::Checks::CardExchangeProjectionFinding < Views::HealthCheck::Checks::FindingBase
  def view_template
    finding_shell(
      title: "##{row[:id]} · #{row[:description]}",
      subtitle: "#{formatted_date(row[:date])} · #{I18n.t("health_check.details.statuses.#{row[:paid] ? 'paid' : 'pending'}")}",
      href: card_transaction_path(row[:id])
    ) do
      div(class: "space-y-4 p-4") do
        issue_chips(row[:issues], warnings: row[:warnings])
        div(class: "grid gap-3 sm:grid-cols-2 lg:grid-cols-4") do
          metric(I18n.t("health_check.details.fields.card_total"), money(row[:card_price]))
          metric(I18n.t("health_check.details.fields.expected_total"), money(row[:expected_total]))
          metric(I18n.t("health_check.details.fields.actual_total"), money(row[:actual_total]))
          metric(I18n.t("health_check.details.fields.projected_rows"), Array(row[:actual_rows]).size)
        end
        capability_reason
      end
    end
  end

  private

  def issue_translation_key(code)
    "health_check.details.issue_codes.card_exchange_projection.#{code}"
  end
end
