# frozen_string_literal: true

class Views::HealthCheck::Checks::ExchangeTrioFinding < Views::HealthCheck::Checks::FindingBase
  def view_template
    source = row[:source].to_h
    finding_shell(
      title: "##{source[:id]} · #{source[:description]}",
      subtitle: "#{formatted_date(source[:date])} · #{row[:chain_kind].to_s.humanize}",
      href: transaction_path(source)
    ) do
      div(class: "space-y-4 p-4") do
        issue_chips(row[:issues], warnings: row[:warnings])
        div(class: "grid gap-3 sm:grid-cols-2 lg:grid-cols-4") do
          metric(I18n.t("health_check.details.fields.intent"), row[:intent].to_s.humanize)
          metric(I18n.t("health_check.details.fields.message"), row.dig(:message, :id) || "—")
          metric(I18n.t("health_check.details.fields.conversation"), row.dig(:message, :conversation_id) || "—")
          metric(I18n.t("health_check.details.fields.proposed_changes"), Array(row[:proposed_changes]).size)
        end
        capability_reason
      end
    end
  end

  private

  def transaction_path(source)
    return card_transaction_path(source[:id]) if source[:type] == "CardTransaction"

    cash_transaction_path(source[:id]) if source[:type] == "CashTransaction"
  end

  def issue_translation_key(code)
    "health_check.details.issue_codes.exchange_trio.#{code}"
  end
end
