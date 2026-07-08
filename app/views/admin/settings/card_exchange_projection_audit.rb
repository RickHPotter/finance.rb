# frozen_string_literal: true

class Views::Admin::Settings::CardExchangeProjectionAudit < Views::Base
  include TranslateHelper

  attr_reader :rows

  def initialize(rows:)
    @rows = rows
  end

  def view_template
    turbo_frame_tag :settings_card_exchange_projection_audit_content do
      div(class: "space-y-4 text-left text-black dark:text-slate-100") do
        div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
          h2(class: "text-lg font-bold text-slate-900 dark:text-slate-100") { I18n.t("settings.card_exchange_projection_audit.title") }
          p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("settings.card_exchange_projection_audit.description") }
          p(class: "mt-2 text-xs font-semibold uppercase tracking-wide text-stone-600 dark:text-slate-400") do
            plain "#{I18n.t('settings.card_exchange_projection_audit.context')}: "
            plain(rows.first&.dig(:context, :name) || "-")
          end
        end

        if rows.empty?
          render_filter_bar
          empty_state
        else
          summary_card
          render_filter_bar
          div(class: "space-y-4") { rows.each { |row| audit_card(row) } }
        end
      end
    end
  end

  private

  def empty_state
    empty_class = "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500 " \
                  "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-400"

    div(class: empty_class) do
      I18n.t("settings.card_exchange_projection_audit.empty")
    end
  end

  def summary_card
    div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
      div(class: "grid gap-3 md:grid-cols-3") do
        summary_stat(I18n.t("settings.card_exchange_projection_audit.summary.rows"), rows.count)
        summary_stat(I18n.t("settings.card_exchange_projection_audit.summary.shape_mismatches"), rows.count do |row|
          row.fetch(:warnings, []).include?("projection_shape_mismatch") || row[:issues].include?("source_allocation_mismatch")
        end)
        summary_stat(I18n.t("settings.card_exchange_projection_audit.summary.duplicate_buckets"), rows.count do |row|
          row.fetch(:warnings, []).include?("duplicate_projection_buckets")
        end)
      end
    end
  end

  def render_filter_bar
    div(class: "flex flex-wrap gap-2") do
      filter_button("pending")
      filter_button("paid")
    end
  end

  def filter_button(name)
    active = current_status_filter == name
    button_classes = active ? "bg-slate-900 text-white dark:bg-sky-500" : "bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-200"

    form(action: card_exchange_projection_audit_admin_settings_path, method: "get") do
      input(type: "hidden", name: "status_filter", value: name)
      button(type: :submit, class: "rounded-full px-3 py-1 text-sm font-semibold transition-colors #{button_classes}") do
        I18n.t("settings.card_exchange_projection_audit.filters.#{name}")
      end
    end
  end

  def audit_card(row)
    div(class: "overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
      div(class: "flex flex-wrap items-start justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
        div(class: "space-y-1") do
          div(class: "flex flex-wrap items-center gap-2") do
            h3(class: "text-base font-bold text-slate-900 dark:text-slate-100") { "##{row[:id]} · #{row[:description]}" }
            a(href: card_transaction_path(row[:id]), class: "text-xs font-semibold text-sky-700 hover:underline", data: { turbo_frame: "_top" }) do
              I18n.t("settings.card_exchange_projection_audit.open")
            end
          end

          p(class: "text-xs text-slate-600 dark:text-slate-400") do
            plain "#{I18n.t('settings.card_exchange_projection_audit.date')}: #{I18n.l(row[:date], format: :short)}"
            plain " · "
            plain "#{I18n.t('settings.card_exchange_projection_audit.month_year')}: #{row[:month_year]}"
            plain " · "
            plain "#{I18n.t('settings.card_exchange_projection_audit.context')}: #{row.dig(:context, :name)}"
            plain " · "
            plain "#{I18n.t('settings.card_exchange_projection_audit.status_label')}: #{status_text_for(row)}"
          end
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          row[:issues].each do |issue|
            meta_chip(I18n.t("settings.card_exchange_projection_audit.issue_codes.#{issue}"), issue_chip_class(issue))
          end
          row.fetch(:warnings, []).each do |warning|
            meta_chip(I18n.t("settings.card_exchange_projection_audit.issue_codes.#{warning}"), warning_chip_class)
          end
        end
      end

      div(class: "grid gap-3 px-4 py-4 md:grid-cols-3") do
        metric(I18n.t("settings.card_exchange_projection_audit.metrics.card_total"), row[:card_price].abs)
        metric(I18n.t("settings.card_exchange_projection_audit.metrics.expected_total"), row[:expected_total])
        metric(I18n.t("settings.card_exchange_projection_audit.metrics.actual_total"), row[:actual_total])
      end

      if row[:allocation_issue].present?
        div(class: "border-t border-rose-200 bg-rose-50 px-4 py-3") do
          h4(class: "text-xs font-semibold uppercase tracking-wide text-rose-900") { I18n.t("settings.card_exchange_projection_audit.allocation_rows.title") }
          p(class: "mt-1 text-xs text-rose-800") { I18n.t("settings.card_exchange_projection_audit.allocation_rows.description") }
          allocation_issue_row(row[:allocation_issue])
        end
      end

      div(class: "grid gap-4 border-t border-slate-200 px-4 py-4 dark:border-slate-700 lg:grid-cols-2") do
        rows_column(I18n.t("settings.card_exchange_projection_audit.expected_rows"), row[:expected_rows], expected: true)
        rows_column(I18n.t("settings.card_exchange_projection_audit.actual_rows"), row[:actual_rows], expected: false)
      end
    end
  end

  def rows_column(title, rows_collection, expected:)
    div(class: "space-y-2") do
      h4(class: "text-xs font-semibold uppercase tracking-wide text-slate-500") { title }

      rows_collection.each do |entry|
        div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-800 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200") do
          p(class: "font-semibold text-slate-900 dark:text-slate-100") do
            plain("#{I18n.t('settings.card_exchange_projection_audit.bucket')}: #{entry[:month]}/#{entry[:year]}")
            plain " · "
            plain from_cent_based_to_float(entry[:price], "R$")
          end

          if expected
            p(class: "text-xs text-slate-600 dark:text-slate-400") { "#{I18n.t('settings.card_exchange_projection_audit.installment_number')}: #{entry[:number]}" }
          else
            p(class: "text-xs text-slate-600 dark:text-slate-400") { "Exchange ##{entry[:id]} · Cash ##{entry[:cash_transaction_id]} · #{entry[:entity_name]}" }
          end
        end
      end
    end
  end

  def metric(label, value)
    div(class: "rounded-xl border border-slate-200 bg-white px-3 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-2 text-lg font-bold text-slate-900 dark:text-slate-100") { from_cent_based_to_float(value, "R$") }
    end
  end

  def summary_stat(label, value)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-2 text-lg font-bold text-slate-900 dark:text-slate-100") { value.to_s }
    end
  end

  def meta_chip(text, classes)
    span(class: "inline-flex items-center rounded-full px-2.5 py-1 #{classes}") { text }
  end

  def allocation_issue_row(allocation_row)
    div(class: "mt-3 rounded-xl border border-rose-200 bg-white px-3 py-2 text-sm text-slate-800 dark:border-rose-500/40 dark:bg-slate-900 dark:text-slate-200") do
      div(class: "flex flex-wrap items-start justify-between gap-2") do
        div(class: "space-y-1") do
          p(class: "font-semibold text-slate-900 dark:text-slate-100") do
            plain "#{allocation_row[:transactable_type]} ##{allocation_row[:transactable_id]}"
            plain " · #{allocation_row[:description]}" if allocation_row[:description].present?
          end
          p(class: "text-xs text-slate-600 dark:text-slate-400") { I18n.t("settings.card_exchange_projection_audit.issue_codes.#{allocation_row[:issue_code]}") }
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          meta_chip(
            "#{I18n.t('settings.card_exchange_projection_audit.allocation_rows.transaction_total')}: #{from_cent_based_to_float(allocation_row[:transaction_total],
                                                                                                                                'R$')}",
            "bg-slate-200 text-slate-700"
          )
          meta_chip(
            "#{I18n.t('settings.card_exchange_projection_audit.allocation_rows.allocation_total')}: #{from_cent_based_to_float(allocation_row[:allocation_total],
                                                                                                                               'R$')}",
            "bg-slate-200 text-slate-700"
          )
          meta_chip(
            "#{I18n.t('settings.card_exchange_projection_audit.allocation_rows.missing_amount')}: #{from_cent_based_to_float(allocation_row[:missing_amount], 'R$')}",
            "bg-rose-100 text-rose-900"
          )
        end
      end
    end
  end

  def issue_chip_class(issue)
    return "bg-rose-100 text-rose-800" if issue.include?("mismatch")

    "bg-amber-100 text-amber-900"
  end

  def warning_chip_class
    "bg-sky-100 text-sky-900"
  end

  def current_status_filter
    rows.first&.fetch(:status_filter, "pending") || "pending"
  end

  def status_text_for(row)
    I18n.t("settings.card_exchange_projection_audit.filters.#{row[:paid] ? 'paid' : 'pending'}")
  end
end
