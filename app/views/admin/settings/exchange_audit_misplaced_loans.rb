# frozen_string_literal: true

class Views::Admin::Settings::ExchangeAuditMisplacedLoans < Views::Base
  include TranslateHelper

  attr_reader :result, :result_only, :rows

  def initialize(rows:, result: nil, result_only: false)
    @rows = rows
    @result = result
    @result_only = result_only
  end

  def view_template
    return render_result if result_only

    turbo_frame_tag :settings_exchange_return_audit_misplaced_loans_content do
      div(class: "space-y-3 text-left text-black dark:text-slate-100") do
        div(id: :settings_exchange_return_audit_misplaced_loans_result) { render_result if result.present? }
        header
        rows.empty? ? empty_state : row_list
      end
    end
  end

  private

  def header
    div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
      h3(class: "text-base font-bold text-slate-900 dark:text-slate-100") { I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.title") }
      p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.description") }
    end
  end

  def render_result
    div(class: result_panel_class) do
      p(class: "font-semibold") do
        I18n.t(
          "settings.exchange_audit.issue_buckets.misplaced_loans.converted",
          source_id: result[:source_id],
          count: result[:updated_message_count]
        )
      end
    end
  end

  def empty_state
    div(class: empty_panel_class) do
      I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.empty")
    end
  end

  def row_list
    div(class: "space-y-3") do
      rows.each { |row| misplaced_loan_card(row) }
    end
  end

  def misplaced_loan_card(row)
    div(id: misplaced_loan_row_dom_id(row[:source_id]),
        class: "overflow-hidden rounded-2xl border border-amber-200 bg-white shadow-sm dark:border-amber-500/40 dark:bg-slate-950 dark:shadow-black/30") do
      div(class: "flex flex-wrap items-start justify-between gap-3 border-b border-amber-200 bg-amber-50 px-4 py-3 dark:border-amber-500/40 dark:bg-amber-950/20") do
        div(class: "space-y-1") do
          p(class: "text-sm font-semibold text-slate-900 dark:text-slate-100") { "CashTransaction ##{row[:source_id]} · #{row[:description]}" }
          p(class: "text-xs text-slate-600 dark:text-slate-400") { "#{formatted_time(row[:date])} · #{row[:month_year]}" }
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          meta_chip(total_label(:transaction_total, row[:transaction_total]), "bg-slate-200 text-slate-700")
          meta_chip(total_label(:entity_return_total, row[:entity_return_total]), "bg-slate-200 text-slate-700")
          meta_chip(total_label(:delta, row[:delta]), "bg-amber-200 text-amber-950")
        end
      end

      div(class: "grid gap-3 px-4 py-4 lg:grid-cols-2") do
        impact_card(row)
        entity_card(row)
      end

      div(class: "border-t border-amber-200 bg-amber-50 px-4 py-3 dark:border-amber-500/40 dark:bg-amber-950/20") do
        convert_button(row)
      end
    end
  end

  def impact_card(row)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-900") do
      h4(class: "text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") do
        I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.impact")
      end
      p(class: "mt-2 text-sm text-slate-700 dark:text-slate-300") do
        I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.message_ids", ids: row[:message_ids].join(", "))
      end
    end
  end

  def entity_card(row)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-900") do
      h4(class: "text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { I18n.t("settings.exchange_audit.entities") }
      div(class: "mt-2 space-y-2") do
        row[:entity_rows].each do |entity_row|
          div(class: "rounded-lg bg-white px-3 py-2 text-xs text-slate-700 dark:bg-slate-950 dark:text-slate-300") do
            p(class: "font-semibold text-slate-900 dark:text-slate-100") { "#{entity_row[:entity_name]} · EntityTransaction ##{entity_row[:id]}" }
            p { "#{I18n.t('settings.exchange_audit.price')}: #{from_cent_based_to_float(entity_row[:price], 'R$')}" }
            p { total_label(:price_to_be_returned, entity_row[:price_to_be_returned]) }
          end
        end
      end
    end
  end

  def convert_button(row)
    form(action: convert_misplaced_loan_admin_settings_path, method: "post") do
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "source_transaction_id", value: row[:source_id])
      button(type: :submit, class: "rounded-lg bg-amber-700 px-3 py-2 text-sm font-semibold text-white transition hover:bg-amber-800") do
        I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.convert_button")
      end
    end
  end

  def meta_chip(text, classes)
    span(class: "inline-flex items-center rounded-full px-2.5 py-1 #{classes}") { text }
  end

  def total_label(key, value)
    "#{I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.#{key}")}: #{from_cent_based_to_float(value, 'R$')}"
  end

  def empty_panel_class
    "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500 " \
      "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-400"
  end

  def result_panel_class
    "rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-950 " \
      "dark:border-emerald-500/40 dark:bg-emerald-950/30 dark:text-emerald-100"
  end

  def formatted_time(value)
    return "-" if value.blank?

    I18n.l(value, format: :shorter)
  end

  def misplaced_loan_row_dom_id(source_id)
    "misplaced_loan_row_#{source_id}"
  end
end
