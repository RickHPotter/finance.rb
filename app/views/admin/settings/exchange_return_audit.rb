# frozen_string_literal: true

class Views::Admin::Settings::ExchangeReturnAudit < Views::Base # rubocop:disable Metrics/ClassLength
  include TranslateHelper

  attr_reader :rows

  def initialize(rows:)
    @rows = rows
  end

  def view_template
    turbo_frame_tag :settings_exchange_return_audit_content do
      div(class: "space-y-4 text-left text-black") do
        div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm") do
          h2(class: "text-lg font-bold text-slate-900") { I18n.t("settings.exchange_return_audit.title") }
          p(class: "mt-1 text-sm text-slate-600") { I18n.t("settings.exchange_return_audit.description") }
          p(class: "mt-2 text-xs font-semibold uppercase tracking-wide text-stone-600") do
            plain "#{I18n.t('settings.exchange_return_audit.context')}: "
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
    div(class: "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500") do
      I18n.t("settings.exchange_return_audit.empty")
    end
  end

  def summary_card
    div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm") do
      div(class: "grid gap-3 md:grid-cols-4") do
        summary_stat(I18n.t("settings.exchange_return_audit.summary.rows"), rows.count)
        summary_stat(
          I18n.t("settings.exchange_return_audit.summary.installment_mismatches"),
          rows.count { |row| row[:issues].include?("installments_total_mismatch") }
        )
        summary_stat(
          I18n.t("settings.exchange_return_audit.summary.stale_source_rows"),
          rows.count { |row| row[:issues].include?("stale_linked_source_rows") || row[:issues].include?("source_allocation_mismatch") }
        )
        summary_stat(
          I18n.t("settings.exchange_return_audit.summary.message_replay_mismatches"),
          rows.count { |row| row[:issues].include?("message_replay_payload_mismatch") }
        )
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
    button_classes = active ? "bg-slate-900 text-white" : "bg-slate-200 text-slate-700"

    form(action: exchange_return_audit_admin_settings_path, method: "get") do
      input(type: "hidden", name: "status_filter", value: name)
      button(
        type: :submit,
        class: "rounded-full px-3 py-1 text-sm font-semibold transition-colors #{button_classes}"
      ) { I18n.t("settings.exchange_return_audit.filters.#{name}") }
    end
  end

  def audit_card(row)
    div(class: "overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm") do
      div(class: "flex flex-wrap items-start justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3") do
        div(class: "space-y-1") do
          div(class: "flex flex-wrap items-center gap-2") do
            h3(class: "text-base font-bold text-slate-900") { "##{row[:id]} · #{row[:description]}" }
            a(href: cash_transaction_path(row[:id]), class: "text-xs font-semibold text-sky-700 hover:underline", data: { turbo_frame: "_top" }) do
              I18n.t("settings.exchange_return_audit.open")
            end
          end

          p(class: "text-xs text-slate-600") do
            plain "#{I18n.t('settings.exchange_return_audit.date')}: #{I18n.l(row[:date], format: :short)}"
            plain " · "
            plain "#{I18n.t('settings.exchange_return_audit.month_year')}: #{row[:month_year]}"
            plain " · "
            plain "#{I18n.t('settings.exchange_return_audit.context')}: #{row.dig(:context, :name)}"
            plain " · "
            plain "#{I18n.t('settings.exchange_return_audit.status_label')}: #{I18n.t("settings.exchange_return_audit.filters.#{row[:paid] ? 'paid' : 'pending'}")}"
          end
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          row[:issues].each do |issue|
            meta_chip(I18n.t("settings.exchange_return_audit.issue_codes.#{issue}"), issue_chip_class(issue))
          end
        end
      end

      div(class: "grid gap-3 px-4 py-4 md:grid-cols-2 xl:grid-cols-4") do
        metric(I18n.t("settings.exchange_return_audit.metrics.cash_total"), row[:price])
        metric(I18n.t("settings.exchange_return_audit.metrics.installments_total"), row[:installments_sum])
        metric(I18n.t("settings.exchange_return_audit.metrics.exchange_rows_total"), row[:exchange_rows_sum])
        metric(I18n.t("settings.exchange_return_audit.metrics.source_rows"), row[:linked_source_rows].count, number: true)
      end

      replay_rows(row[:message_replay_rows]) if row[:message_replay_rows].present?
      card_bound_projection_rows(row[:card_bound_projection_rows]) if row[:card_bound_projection_rows].present?

      if row[:linked_source_rows].present?
        div(class: "border-t border-amber-200 bg-amber-50 px-4 py-3") do
          h4(class: "text-xs font-semibold uppercase tracking-wide text-amber-900") { I18n.t("settings.exchange_return_audit.stale_rows.title") }
          p(class: "mt-1 text-xs text-amber-800") { I18n.t("settings.exchange_return_audit.stale_rows.description") }

          div(class: "mt-3 space-y-2") do
            row[:linked_source_rows].each do |source_row|
              stale_row(source_row)
            end
          end
        end
      end

      if row[:source_allocation_rows].present?
        div(class: "border-t border-rose-200 bg-rose-50 px-4 py-3") do
          h4(class: "text-xs font-semibold uppercase tracking-wide text-rose-900") { I18n.t("settings.exchange_return_audit.allocation_rows.title") }
          p(class: "mt-1 text-xs text-rose-800") { I18n.t("settings.exchange_return_audit.allocation_rows.description") }

          div(class: "mt-3 space-y-2") do
            row[:source_allocation_rows].each do |allocation_row|
              allocation_issue_row(allocation_row)
            end
          end
        end
      end
    end
  end

  def stale_row(source_row)
    div(class: "rounded-xl border border-amber-200 bg-white px-3 py-2 text-sm text-slate-800") do
      div(class: "flex flex-wrap items-start justify-between gap-2") do
        div(class: "space-y-1") do
          p(class: "font-semibold text-slate-900") do
            plain "#{source_row[:transactable_type]} ##{source_row[:transactable_id]}"
            plain " · #{source_row[:description]}" if source_row[:description].present?
          end
          p(class: "text-xs text-slate-600") { "EntityTransaction ##{source_row[:entity_transaction_id]}" }
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          meta_chip("#{I18n.t('settings.exchange_return_audit.stale_rows.aggregate')}: #{from_cent_based_to_float(source_row[:aggregate_total], 'R$')}",
                    "bg-slate-200 text-slate-700")
          meta_chip(
            "#{I18n.t('settings.exchange_return_audit.stale_rows.aggregate_exchange_total')}: #{from_cent_based_to_float(source_row[:aggregate_exchange_total],
                                                                                                                         'R$')}",
            "bg-slate-200 text-slate-700"
          )
          meta_chip(
            "#{I18n.t('settings.exchange_return_audit.stale_rows.scoped_exchange_total')}: #{from_cent_based_to_float(source_row[:scoped_exchange_total],
                                                                                                                      'R$')}", "bg-slate-200 text-slate-700"
          )
          meta_chip("#{I18n.t('settings.exchange_return_audit.stale_rows.delta')}: #{from_cent_based_to_float(source_row[:delta], 'R$')}",
                    "bg-amber-100 text-amber-900")
        end
      end
    end
  end

  def metric(label, value, small: false, number: false)
    div(class: "rounded-xl border border-slate-200 bg-white px-3 py-3") do
      p(class: small ? "text-[11px] font-semibold uppercase tracking-wide text-slate-500" : "text-xs font-semibold uppercase tracking-wide text-slate-500") { label }
      p(class: small ? "mt-1 text-base font-bold text-slate-900" : "mt-2 text-lg font-bold text-slate-900") do
        plain(number ? value.to_s : from_cent_based_to_float(value, "R$"))
      end
    end
  end

  def summary_stat(label, value)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-3") do
      p(class: "text-xs font-semibold uppercase tracking-wide text-slate-500") { label }
      p(class: "mt-2 text-lg font-bold text-slate-900") { value.to_s }
    end
  end

  def meta_chip(text, classes)
    span(class: "inline-flex items-center rounded-full px-2.5 py-1 #{classes}") { text }
  end

  def allocation_issue_row(allocation_row)
    div(class: "rounded-xl border border-rose-200 bg-white px-3 py-2 text-sm text-slate-800") do
      div(class: "flex flex-wrap items-start justify-between gap-2") do
        div(class: "space-y-1") do
          p(class: "font-semibold text-slate-900") do
            plain "#{allocation_row[:transactable_type]} ##{allocation_row[:transactable_id]}"
            plain " · #{allocation_row[:description]}" if allocation_row[:description].present?
          end
          p(class: "text-xs text-slate-600") { I18n.t("settings.exchange_return_audit.issue_codes.#{allocation_row[:issue_code]}") }
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          meta_chip(
            "#{I18n.t('settings.exchange_return_audit.allocation_rows.transaction_total')}: #{from_cent_based_to_float(allocation_row[:transaction_total], 'R$')}",
            "bg-slate-200 text-slate-700"
          )
          meta_chip(
            "#{I18n.t('settings.exchange_return_audit.allocation_rows.allocation_total')}: #{from_cent_based_to_float(allocation_row[:allocation_total], 'R$')}",
            "bg-slate-200 text-slate-700"
          )
          meta_chip("#{I18n.t('settings.exchange_return_audit.allocation_rows.missing_amount')}: #{from_cent_based_to_float(allocation_row[:missing_amount], 'R$')}",
                    "bg-rose-100 text-rose-900")
        end
      end
    end
  end

  def replay_rows(message_replay_rows)
    div(class: "border-t border-violet-200 bg-violet-50 px-4 py-3") do
      h4(class: "text-xs font-semibold uppercase tracking-wide text-violet-900") { I18n.t("settings.exchange_return_audit.message_replay_rows.title") }
      p(class: "mt-1 text-xs text-violet-800") { I18n.t("settings.exchange_return_audit.message_replay_rows.description") }

      div(class: "mt-3 space-y-2") do
        message_replay_rows.each do |message_row|
          replay_row(message_row)
        end
      end
    end
  end

  def card_bound_projection_rows(rows)
    div(class: "border-t border-orange-200 bg-orange-50 px-4 py-3") do
      h4(class: "text-xs font-semibold uppercase tracking-wide text-orange-900") { I18n.t("settings.exchange_return_audit.card_bound_projection_rows.title") }
      p(class: "mt-1 text-xs text-orange-800") { I18n.t("settings.exchange_return_audit.card_bound_projection_rows.description") }

      div(class: "mt-3 space-y-2") do
        rows.each do |row|
          card_bound_projection_row(row)
        end
      end
    end
  end

  def card_bound_projection_row(row)
    div(class: "rounded-xl border border-orange-200 bg-white px-3 py-2 text-sm text-slate-800") do
      div(class: "flex flex-wrap items-start justify-between gap-2") do
        div(class: "space-y-1") do
          p(class: "font-semibold text-slate-900") do
            plain "#{row[:source_type]} ##{row[:source_id]}"
            plain " · #{row[:source_description]}" if row[:source_description].present?
          end
          p(class: "text-xs text-slate-600") do
            plain "Exchange ##{row[:exchange_id]}"
            plain " · #{row[:entity_name]}" if row[:entity_name].present?
            plain " · #{I18n.t("settings.exchange_return_audit.issue_codes.#{row[:issue_code]}")}"
          end
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          meta_chip("#{I18n.t('settings.exchange_return_audit.card_bound_projection_rows.number')}: #{row[:number]}", "bg-slate-200 text-slate-700")
          meta_chip(card_bound_projection_bucket_text(:exchange_bucket, row[:exchange_month], row[:exchange_year]), "bg-orange-100 text-orange-900")
          meta_chip(card_bound_projection_bucket_text(:expected_bucket, row[:expected_month], row[:expected_year]), "bg-slate-200 text-slate-700")
          meta_chip("#{I18n.t('settings.exchange_return_audit.card_bound_projection_rows.exchange_price')}: #{from_cent_based_to_float(row[:exchange_price], 'R$')}",
                    "bg-orange-100 text-orange-900")
          meta_chip("#{I18n.t('settings.exchange_return_audit.card_bound_projection_rows.expected_price')}: #{from_cent_based_to_float(row[:expected_price], 'R$')}",
                    "bg-slate-200 text-slate-700")
        end
      end
    end
  end

  def card_bound_projection_bucket_text(key, month, year)
    "#{I18n.t("settings.exchange_return_audit.card_bound_projection_rows.#{key}")}: #{format_bucket(month, year)}"
  end

  def replay_row(message_row)
    div(class: "rounded-xl border border-violet-200 bg-white px-3 py-2 text-sm text-slate-800") do
      div(class: "flex flex-wrap items-start justify-between gap-2") do
        div(class: "space-y-1") do
          p(class: "font-semibold text-slate-900") do
            plain "#{I18n.t('settings.exchange_return_audit.message_replay_rows.message')} ##{message_row[:message_id]}"
            plain " · #{message_row[:preview]}" if message_row[:preview].present?
          end
          p(class: "text-xs text-slate-600") do
            plain "#{I18n.t('settings.exchange_return_audit.message_replay_rows.conversation')} ##{message_row[:conversation_id]}"
            plain " · #{I18n.t('settings.exchange_return_audit.message_replay_rows.intent')}: #{message_row[:intent]}" if message_row[:intent].present?
          end
        end

        div(class: "flex flex-wrap gap-2 text-xs font-semibold") do
          message_row[:diffs].each do |attribute, diff|
            replay_diff_chip(attribute, diff)
          end
        end
      end
    end
  end

  def replay_diff_chip(attribute, diff)
    if attribute == "cash_installments_attributes"
      count = diff.count
      meta_chip("#{I18n.t('settings.exchange_return_audit.message_replay_rows.installments')}: #{count}", "bg-violet-100 text-violet-900")
    else
      meta_chip("#{attribute}: #{format_replay_value(diff[:local])} / #{format_replay_value(diff[:payload])}", "bg-violet-100 text-violet-900")
    end
  end

  def format_replay_value(value)
    return from_cent_based_to_float(value, "R$") if value.is_a?(Integer)
    return I18n.l(value, format: :short) if value.respond_to?(:strftime)

    value.to_s
  end

  def format_bucket(month, year)
    return "-" if month.blank? || year.blank?

    "#{month.to_s.rjust(2, '0')}/#{year}"
  end

  def issue_chip_class(issue)
    return "bg-violet-100 text-violet-900" if issue == "message_replay_payload_mismatch"
    return "bg-orange-100 text-orange-900" if issue == "card_bound_bill_projection_mismatch"
    return "bg-rose-100 text-rose-800" if issue.include?("mismatch")

    "bg-amber-100 text-amber-900"
  end

  def current_status_filter
    rows.first&.fetch(:status_filter, "pending") || "pending"
  end
end
