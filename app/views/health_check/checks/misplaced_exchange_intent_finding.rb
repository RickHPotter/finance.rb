# frozen_string_literal: true

class Views::HealthCheck::Checks::MisplacedExchangeIntentFinding < Views::HealthCheck::Checks::FindingBase
  def view_template
    finding_shell(
      title: "##{row[:source_id]} · #{row[:description]}",
      subtitle: "#{formatted_date(row[:date])} · #{row[:month_year]}",
      href: cash_transaction_path(row[:source_id])
    ) do
      div(class: "space-y-4 p-4") do
        issue_chips([ "misplaced_exchange_intent" ])
        div(class: "grid gap-3 sm:grid-cols-2 lg:grid-cols-4") do
          metric(I18n.t("health_check.details.fields.transaction_total"), money(row[:transaction_total]))
          metric(I18n.t("health_check.details.fields.entity_return_total"), money(row[:entity_return_total]))
          metric(I18n.t("health_check.details.fields.delta"), money(row[:delta]))
          metric(I18n.t("health_check.details.fields.affected_messages"), Array(row[:message_ids]).size)
        end
        capability_reason
      end
    end
  end
end
