# frozen_string_literal: true

class Views::Admin::Settings::ExchangeAudit < Views::Base # rubocop:disable Metrics/ClassLength
  include TranslateHelper

  attr_reader :apply_result, :middle_overrides, :receiver_overrides, :reference_audit, :rows

  def initialize(rows:, middle_overrides: {}, receiver_overrides: {}, reference_audit: nil, apply_result: nil)
    @apply_result = apply_result
    @middle_overrides = middle_overrides
    @receiver_overrides = receiver_overrides
    @reference_audit = reference_audit || { candidates: [] }
    @rows = rows
  end

  def view_template
    turbo_frame_tag :settings_exchange_audit_content do
      div(class: "space-y-4 text-left text-black", data: { controller: "naming-tabs", naming_tabs_current_value: "pending" }) do
        render_apply_result if apply_result.present?

        div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm") do
          h2(class: "text-lg font-bold text-slate-900") { I18n.t("settings.exchange_audit.title") }
          p(class: "mt-1 text-sm text-slate-600") { I18n.t("settings.exchange_audit.description") }
        end

        div(class: "flex flex-wrap gap-2") do
          filter_button(name: "pending", count: pending_rows.count)
          filter_button(name: "done", count: done_rows.count)
        end

        div(data: { naming_tabs_target: "panel", naming_tabs_name: "pending" }) do
          render_rows(pending_rows)
        end

        div(class: "hidden", data: { naming_tabs_target: "panel", naming_tabs_name: "done" }) do
          render_rows(done_rows)
        end
      end
    end
  end

  private

  def render_rows(collection)
    if collection.empty?
      empty_state
    else
      div(class: "space-y-4") do
        collection.each do |row|
          trio_card(row)
        end
      end
    end
  end

  def pending_rows
    @pending_rows ||= rows.select { |row| row[:status] == "pending" }
  end

  def done_rows
    @done_rows ||= rows.select { |row| row[:status] == "done" }
  end

  def filter_button(name:, count:)
    button(
      type: :button,
      class: "rounded-full bg-slate-200 px-3 py-1 text-sm font-semibold text-slate-700 transition-colors",
      data: { action: "click->naming-tabs#select", naming_tabs_target: "tab", naming_tabs_name: name }
    ) do
      plain I18n.t("settings.exchange_audit.filters.#{name}")
      plain " (#{count})"
    end
  end

  def empty_state
    div(class: "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500") do
      I18n.t("settings.exchange_audit.empty")
    end
  end

  def render_apply_result
    div(class: "rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-950") do
      if apply_result[:updated_row_count].positive?
        p(class: "font-semibold") { I18n.t("settings.exchange_audit.apply_result.updated", count: apply_result[:updated_row_count]) }
      else
        p(class: "font-semibold") { I18n.t("settings.exchange_audit.apply_result.skipped") }
      end

      p(class: "mt-1 text-xs text-emerald-900") { apply_result[:skipped].map { |entry| entry[:reason] }.uniq.join(", ") } if apply_result[:skipped].present?
    end
  end

  def trio_card(row)
    div(class: "overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm") do
      div(class: "flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3") do
        div(class: "space-y-1") do
          div(class: "text-sm font-semibold text-slate-900") do
            plain "#{I18n.t('settings.exchange_audit.message')} ##{row.dig(:message, :id)}"
            plain " · ##{row.dig(:message, :conversation_id)}"
          end
          p(class: "text-xs text-slate-600") { row.dig(:message, :body) }
        end

        div(class: "flex flex-wrap items-center gap-2 text-xs font-semibold") do
          meta_chip(status_chip_label(row), status_chip_class(row))
          meta_chip(I18n.t("settings.exchange_audit.chain_kinds.#{row[:chain_kind]}"), "bg-indigo-100 text-indigo-800")
          meta_chip("#{I18n.t('settings.exchange_audit.action')}: #{row[:message][:action]}", "bg-sky-100 text-sky-800")
          meta_chip("#{I18n.t('settings.exchange_audit.actionable')}: #{boolean_label(row.dig(:message, :actionable))}", "bg-violet-100 text-violet-800")
          meta_chip("#{I18n.t('settings.exchange_audit.intent')}: #{row[:intent].presence || '-'}", "bg-amber-100 text-amber-800")
          meta_chip("#{I18n.t('settings.exchange_audit.scenario')}: #{scenario_label(row)}", "bg-slate-200 text-slate-700")
        end
      end

      div(class: "grid gap-4 px-4 py-4 lg:grid-cols-3") do
        column(title: I18n.t("settings.exchange_audit.source"), user: row[:sender], transaction: row[:source])
        column(title: I18n.t("settings.exchange_audit.middle"), user: row[:sender], transaction: row[:middle], count: row[:middle_candidates_count], row:)
        end_column(row)
      end

      if row[:proposed_changes].present?
        div(class: "border-t border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950") do
          strong(class: "font-semibold") { "#{I18n.t('settings.exchange_audit.proposed_changes')}: " }

          ul(class: "mt-2 space-y-1") do
            row[:proposed_changes].each do |change|
              li { proposed_change_label(change) }
            end
          end

          apply_controls(row)
        end
      end

      return if row[:issues].blank?

      div(class: "border-t border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-900") do
        strong(class: "font-semibold") { "#{I18n.t('settings.exchange_audit.issues')}: " }
        plain row[:issues].map { |issue| issue_label(issue) }.join(", ")
      end
    end
  end

  def end_column(row)
    div(class: "space-y-3") do
      h3(class: "text-xs font-semibold uppercase tracking-wide text-slate-500") { I18n.t("settings.exchange_audit.end") }
      user_meta(I18n.t("settings.exchange_audit.receiver"), row[:receiver])

      if row[:end_kind] == "loan_receiver_combo"
        loan_end_card(label: I18n.t("settings.exchange_audit.receiver_exchange"), transaction: row[:end_transactions][0])
        loan_end_card(label: I18n.t("settings.exchange_audit.receiver_exchange_return"), transaction: row[:end_transactions][1])
      else
        transaction_card(row[:end_transactions][0], title: I18n.t("settings.exchange_audit.shared_return"))
      end

      receiver_candidate_selector(row) if row_requires_receiver_selection?(row)
    end
  end

  def column(title:, user:, transaction:, count: nil, row: nil)
    div(class: "space-y-3") do
      h3(class: "text-xs font-semibold uppercase tracking-wide text-slate-500") { title }
      user_meta(I18n.t("settings.exchange_audit.sender"), user)
      transaction_card(transaction, count:)
      middle_candidate_selector(row) if row.present? && row_requires_middle_selection?(row)
    end
  end

  def loan_end_card(label:, transaction:)
    transaction_card(transaction, title: label)
  end

  def user_meta(label, user)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-2") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-slate-500") { label }
      if user.present?
        p(class: "mt-1 text-sm font-semibold text-slate-900") { "#{user[:first_name]} ##{user[:id]}" }
        p(class: "text-xs text-slate-600") { user[:email] }
      else
        p(class: "mt-1 text-sm text-slate-500") { I18n.t("settings.exchange_audit.missing") }
      end
    end
  end

  def transaction_card(transaction, title: nil, count: nil)
    div(class: "rounded-xl border border-slate-200 bg-white p-3") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-slate-500") { title } if title.present?

      if transaction.blank?
        p(class: "mt-1 text-sm text-slate-500") { I18n.t("settings.exchange_audit.missing") }
      else
        p(class: "text-sm font-semibold text-slate-900") { "#{transaction[:type]} ##{transaction[:id]}" }
        p(class: "mt-1 text-sm text-slate-700") { transaction[:description] }
        p(class: "mt-2 text-xs text-slate-600") { "#{I18n.t('settings.exchange_audit.date')}: #{formatted_time(transaction[:date])}" }
        p(class: "text-xs text-slate-600") { "#{I18n.t('settings.exchange_audit.price')}: #{from_cent_based_to_float(transaction[:price], 'R$')}" }
        p(class: "text-xs text-slate-600") { "#{I18n.t('settings.exchange_audit.context')}: ##{transaction[:context_id]} · #{transaction[:month_year]}" }
        p(class: "text-xs text-slate-600") { "#{I18n.t('settings.exchange_audit.categories')}: #{format_list(transaction[:category_names])}" }
        p(class: "text-xs text-slate-600") { "#{I18n.t('settings.exchange_audit.entities')}: #{format_list(transaction[:entity_names])}" }
        div(class: "mt-2 space-y-1 text-xs") do
          p(class: "text-slate-600") { "#{I18n.t('settings.exchange_audit.current_reference')}: #{reference_label(transaction[:current_reference])}" }
          p(class: "text-slate-600") { "#{I18n.t('settings.exchange_audit.expected_reference')}: #{reference_label(transaction[:expected_reference])}" }
          meta_chip(I18n.t("settings.exchange_audit.reference_statuses.#{transaction[:reference_status]}"),
                    reference_status_chip_class(transaction[:reference_status]))
        end
        p(class: "mt-1 text-[11px] text-slate-500") { I18n.t("settings.exchange_audit.options_count", count:) } if count.to_i > 1
      end
    end
  end

  def middle_candidate_selector(row)
    div(class: "rounded-xl border border-indigo-200 bg-indigo-50 p-3") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-indigo-700") { I18n.t("settings.exchange_audit.middle_selection.title") }
      p(class: "mt-1 text-xs text-indigo-900") { I18n.t("settings.exchange_audit.middle_selection.description") }

      form(action: exchange_audit_admin_settings_path, method: "get", class: "mt-3 space-y-3") do
        preserved_middle_overrides(except_source_transaction_id: row.dig(:source, :id))
        preserved_receiver_overrides(except_source_transaction_id: row.dig(:source, :id))

        select(
          name: "middle_overrides[#{row.dig(:source, :id)}]",
          class: "w-full rounded-lg border border-indigo-300 bg-white px-3 py-2 text-sm text-slate-900"
        ) do
          row[:middle_candidates].each do |candidate|
            option(value: candidate[:id], selected: candidate[:id] == selected_middle_candidate_id(row)) do
              middle_candidate_label(candidate)
            end
          end
        end

        button(
          type: :submit,
          class: "rounded-lg bg-indigo-600 px-3 py-2 text-sm font-semibold text-white hover:bg-indigo-700"
        ) { I18n.t("settings.exchange_audit.middle_selection.submit") }
      end
    end
  end

  def apply_controls(row)
    candidate = audit_candidate_for(row)
    return if candidate.blank?

    div(class: "mt-3 flex flex-wrap items-center gap-2") do
      if candidate[:supported]
        form(action: apply_exchange_audit_admin_settings_path, method: "post") do
          input(type: "hidden", name: "_method", value: "patch")
          input(type: "hidden", name: "source_transaction_id", value: row.dig(:source, :id))
          preserved_middle_overrides(except_source_transaction_id: nil)
          preserved_receiver_overrides(except_source_transaction_id: nil)
          button(
            type: :submit,
            class: "rounded-lg bg-emerald-600 px-3 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          ) { I18n.t("settings.exchange_audit.apply_button") }
        end
      elsif candidate[:unsupported_reason].present?
        p(class: "text-xs font-semibold text-rose-900") do
          I18n.t("settings.exchange_audit.apply_unavailable", reason: issue_label(candidate[:unsupported_reason]))
        end
      end
    end
  end

  def receiver_candidate_selector(row)
    div(class: "rounded-xl border border-sky-200 bg-sky-50 p-3") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-sky-700") { I18n.t("settings.exchange_audit.receiver_selection.title") }
      p(class: "mt-1 text-xs text-sky-900") { I18n.t("settings.exchange_audit.receiver_selection.description") }

      form(action: exchange_audit_admin_settings_path, method: "get", class: "mt-3 space-y-3") do
        preserved_middle_overrides(except_source_transaction_id: nil)
        preserved_receiver_overrides(except_source_transaction_id: row.dig(:source, :id))

        select(
          name: "receiver_overrides[#{row.dig(:source, :id)}]",
          class: "w-full rounded-lg border border-sky-300 bg-white px-3 py-2 text-sm text-slate-900"
        ) do
          row[:receiver_candidates].each do |candidate|
            option(value: candidate[:id], selected: candidate[:id] == selected_receiver_candidate_id(row)) do
              receiver_candidate_label(candidate)
            end
          end
        end

        button(
          type: :submit,
          class: "rounded-lg bg-sky-600 px-3 py-2 text-sm font-semibold text-white hover:bg-sky-700"
        ) { I18n.t("settings.exchange_audit.receiver_selection.submit") }
      end
    end
  end

  def meta_chip(text, classes)
    span(class: "rounded-full px-2 py-1 #{classes}") { text }
  end

  def scenario_label(row)
    row.dig(:message, :scenario_key).presence || I18n.t("settings.exchange_audit.main")
  end

  def formatted_time(value)
    return "-" if value.blank?

    I18n.l(value, format: :shorter)
  end

  def format_list(values)
    values.presence&.join(", ") || "-"
  end

  def status_chip_label(row)
    I18n.t("settings.exchange_audit.filters.#{row[:status]}")
  end

  def status_chip_class(row)
    row[:status] == "pending" ? "bg-rose-100 text-rose-800" : "bg-emerald-100 text-emerald-800"
  end

  def boolean_label(value)
    value ? I18n.t("settings.exchange_audit.yes") : I18n.t("settings.exchange_audit.no")
  end

  def issue_label(issue)
    I18n.t("settings.exchange_audit.issue_codes.#{issue}", default: issue)
  end

  def reference_label(reference)
    return I18n.t("settings.exchange_audit.no_reference") if reference.blank?

    "#{reference[:type]} ##{reference[:id]}"
  end

  def reference_status_chip_class(status)
    case status
    when "ok"
      "bg-emerald-100 text-emerald-800"
    when "missing"
      "bg-amber-100 text-amber-900"
    else
      "bg-rose-100 text-rose-800"
    end
  end

  def proposed_change_label(change)
    transaction = change[:transaction]
    from_reference = reference_label(change[:from_reference])
    to_reference = reference_label(change[:to_reference])

    I18n.t(
      "settings.exchange_audit.change_actions.#{change[:action]}",
      node: I18n.t("settings.exchange_audit.node_labels.#{change[:node_key]}"),
      transaction: "#{transaction[:type]} ##{transaction[:id]}",
      from: from_reference,
      to: to_reference
    )
  end

  def audit_candidate_for(row)
    reference_audit.fetch(:candidates, []).find { |candidate| candidate[:source_transaction_id] == row.dig(:source, :id) }
  end

  def row_requires_middle_selection?(row)
    row[:middle_candidates].to_a.size > 1
  end

  def row_requires_receiver_selection?(row)
    row[:receiver_candidates].to_a.any?
  end

  def selected_middle_candidate_id(row)
    row[:selected_middle_id] || middle_overrides[row.dig(:source, :id)] || row.dig(:middle, :id) || row.dig(:middle_candidates, 0, :id)
  end

  def selected_receiver_candidate_id(row)
    row[:selected_receiver_id] || receiver_overrides[row.dig(:source, :id)] || row.dig(:end_transactions, 0, :id) || row.dig(:receiver_candidates, 0, :id)
  end

  def middle_candidate_label(candidate)
    [
      "##{candidate[:id]}",
      candidate[:description],
      "#{I18n.t('settings.exchange_audit.entities')}: #{format_list(candidate[:entity_names])}",
      formatted_time(candidate[:date]),
      from_cent_based_to_float(candidate[:price], "R$")
    ].compact.join(" · ")
  end

  def receiver_candidate_label(candidate)
    [
      "##{candidate[:id]}",
      candidate[:description],
      "#{I18n.t('settings.exchange_audit.categories')}: #{format_list(candidate[:category_names])}",
      "#{I18n.t('settings.exchange_audit.entities')}: #{format_list(candidate[:entity_names])}",
      formatted_time(candidate[:date]),
      from_cent_based_to_float(candidate[:price], "R$")
    ].compact.join(" · ")
  end

  def preserved_middle_overrides(except_source_transaction_id:)
    middle_overrides.each do |source_id, middle_id|
      next if except_source_transaction_id.present? && source_id.to_i == except_source_transaction_id.to_i

      input(type: "hidden", name: "middle_overrides[#{source_id}]", value: middle_id)
    end
  end

  def preserved_receiver_overrides(except_source_transaction_id:)
    receiver_overrides.each do |source_id, receiver_id|
      next if except_source_transaction_id.present? && source_id.to_i == except_source_transaction_id.to_i

      input(type: "hidden", name: "receiver_overrides[#{source_id}]", value: receiver_id)
    end
  end
end
