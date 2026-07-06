# frozen_string_literal: true

class Views::Admin::Settings::ExchangeAudit < Views::Base # rubocop:disable Metrics/ClassLength
  include TranslateHelper

  attr_reader :apply_result, :connections, :middle_overrides, :receiver_overrides, :reference_audit, :rows, :selected_connected_user_id

  def initialize(rows:, middle_overrides: {}, receiver_overrides: {}, **options)
    @apply_result = options.fetch(:apply_result, nil)
    @connections = options.fetch(:connections, [])
    @middle_overrides = middle_overrides
    @receiver_overrides = receiver_overrides
    @reference_audit = options.fetch(:reference_audit, nil) || { candidates: [] }
    @rows = rows
    @selected_connected_user_id = options.fetch(:selected_connected_user_id, nil)
  end

  def view_template
    turbo_frame_tag :settings_exchange_audit_content do
      div(class: "space-y-4 text-left text-black dark:text-slate-100", data: { controller: "naming-tabs", naming_tabs_current_value: "pending" }) do
        render_apply_result if apply_result.present?

        div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
          h2(class: "text-lg font-bold text-slate-900 dark:text-slate-100") { I18n.t("settings.exchange_audit.title") }
          p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("settings.exchange_audit.description") }
        end

        render_connection_scope
        render_connection_summary if selected_connection.present?

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

  def render_connection_scope
    return if connections.blank?

    div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
      h3(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700 dark:text-slate-300") { I18n.t("settings.exchange_audit.connection_scope.title") }
      p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("settings.exchange_audit.connection_scope.description") }

      div(class: "mt-3 flex flex-wrap gap-2") do
        connections.each do |connection|
          form(action: exchange_audit_admin_settings_path, method: "get") do
            input(type: "hidden", name: "connected_user_id", value: connection[:connected_user_id])
            preserved_middle_overrides(except_source_transaction_id: nil)
            preserved_receiver_overrides(except_source_transaction_id: nil)

            button(
              type: :submit,
              class: connection_button_class(connection)
            ) { connection_button_label(connection) }
          end
        end
      end
    end
  end

  def render_connection_summary
    connection = selected_connection

    div(class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
      div(class: "flex flex-wrap items-start justify-between gap-3") do
        div(class: "space-y-1") do
          h3(class: "text-lg font-bold text-slate-900 dark:text-slate-100") do
            I18n.t("settings.exchange_audit.connection_summary.title", name: connection.dig(:user, :first_name))
          end
          p(class: "text-sm text-slate-600 dark:text-slate-400") { connection.dig(:user, :email) }
        end

        meta_chip(I18n.t("settings.exchange_audit.filters.#{connection[:status]}"), status_chip_class(connection))
      end

      div(class: "mt-4 grid gap-3 md:grid-cols-4") do
        summary_stat(I18n.t("settings.exchange_audit.connection_summary.total_rows"), connection[:row_count])
        summary_stat(I18n.t("settings.exchange_audit.connection_summary.pending_rows"), connection[:pending_count])
        summary_stat(I18n.t("settings.exchange_audit.connection_summary.done_rows"), connection[:done_count])
        summary_stat(I18n.t("settings.exchange_audit.connection_summary.latest_activity"), formatted_time(connection[:latest_message_at]))
      end

      div(class: "mt-4 grid gap-3 md:grid-cols-2") do
        mapping_card(
          title: I18n.t("settings.exchange_audit.connection_summary.your_entities"),
          values: connection[:your_entity_names]
        )
        mapping_card(
          title: I18n.t("settings.exchange_audit.connection_summary.their_entities"),
          values: connection[:their_entity_names]
        )
      end
    end
  end

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
      class: "rounded-full bg-slate-200 px-3 py-1 text-sm font-semibold text-slate-700 transition-colors dark:bg-slate-800 dark:text-slate-200",
      data: { action: "click->naming-tabs#select", naming_tabs_target: "tab", naming_tabs_name: name }
    ) do
      plain I18n.t("settings.exchange_audit.filters.#{name}")
      plain " (#{count})"
    end
  end

  def empty_state
    empty_class = "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500 " \
                  "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-400"

    div(class: empty_class) do
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
    div(class: "overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
      div(class: "flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
        div(class: "space-y-1") do
          div(class: "text-sm font-semibold text-slate-900 dark:text-slate-100") do
            plain "#{I18n.t('settings.exchange_audit.message')} ##{row.dig(:message, :id)}"
            plain " · ##{row.dig(:message, :conversation_id)}"
          end
          p(class: "text-xs text-slate-600 dark:text-slate-400") { row.dig(:message, :body) }
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
    div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { label }
      if user.present?
        p(class: "mt-1 text-sm font-semibold text-slate-900 dark:text-slate-100") { "#{user[:first_name]} ##{user[:id]}" }
        p(class: "text-xs text-slate-600 dark:text-slate-400") { user[:email] }
      else
        p(class: "mt-1 text-sm text-slate-500 dark:text-slate-400") { I18n.t("settings.exchange_audit.missing") }
      end
    end
  end

  def transaction_card(transaction, title: nil, count: nil)
    div(class: "rounded-xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { title } if title.present?

      if transaction.blank?
        p(class: "mt-1 text-sm text-slate-500 dark:text-slate-400") { I18n.t("settings.exchange_audit.missing") }
      else
        p(class: "text-sm font-semibold text-slate-900 dark:text-slate-100") { "#{transaction[:type]} ##{transaction[:id]}" }
        p(class: "mt-1 text-sm text-slate-700 dark:text-slate-300") { transaction[:description] }
        p(class: "mt-2 text-xs text-slate-600 dark:text-slate-400") { "#{I18n.t('settings.exchange_audit.date')}: #{formatted_time(transaction[:date])}" }
        p(class: "text-xs text-slate-600 dark:text-slate-400") do
          "#{I18n.t('settings.exchange_audit.price')}: #{from_cent_based_to_float(transaction[:price], 'R$')}"
        end
        p(class: "text-xs text-slate-600 dark:text-slate-400") do
          "#{I18n.t('settings.exchange_audit.context')}: ##{transaction[:context_id]} · #{transaction[:month_year]}"
        end
        p(class: "text-xs text-slate-600 dark:text-slate-400") { "#{I18n.t('settings.exchange_audit.categories')}: #{format_list(transaction[:category_names])}" }
        p(class: "text-xs text-slate-600 dark:text-slate-400") { "#{I18n.t('settings.exchange_audit.entities')}: #{format_list(transaction[:entity_names])}" }
        div(class: "mt-2 space-y-1 text-xs") do
          p(class: "text-slate-600 dark:text-slate-400") do
            "#{I18n.t('settings.exchange_audit.current_reference')}: #{reference_label(transaction[:current_reference])}"
          end
          p(class: "text-slate-600 dark:text-slate-400") do
            "#{I18n.t('settings.exchange_audit.expected_reference')}: #{reference_label(transaction[:expected_reference])}"
          end
          meta_chip(I18n.t("settings.exchange_audit.reference_statuses.#{transaction[:reference_status]}"),
                    reference_status_chip_class(transaction[:reference_status]))
        end
        p(class: "mt-1 text-[11px] text-slate-500") { I18n.t("settings.exchange_audit.options_count", count:) } if count.to_i > 1
      end
    end
  end

  def middle_candidate_selector(row)
    div(class: "rounded-xl border border-indigo-200 bg-indigo-50 p-3 dark:border-indigo-500/40 dark:bg-indigo-950/30") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-indigo-700 dark:text-indigo-200") { I18n.t("settings.exchange_audit.middle_selection.title") }
      p(class: "mt-1 text-xs text-indigo-900 dark:text-indigo-100") { I18n.t("settings.exchange_audit.middle_selection.description") }

      form(action: exchange_audit_admin_settings_path, method: "get", class: "mt-3 space-y-3") do
        preserved_connected_user_scope
        preserved_middle_overrides(except_source_transaction_id: row.dig(:source, :id))
        preserved_receiver_overrides(except_source_transaction_id: row.dig(:source, :id))

        select(
          name: "middle_overrides[#{row.dig(:source, :id)}]",
          class: audit_select_class("indigo")
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
          preserved_connected_user_scope
          preserved_middle_overrides(except_source_transaction_id: nil)
          preserved_receiver_overrides(except_source_transaction_id: nil)
          button(
            type: :submit,
            class: "rounded-lg bg-emerald-600 px-3 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          ) { I18n.t("settings.exchange_audit.apply_button") }
        end
      elsif candidate[:unsupported_reason].present?
        p(class: "text-xs font-semibold text-rose-900 dark:text-rose-300") do
          I18n.t("settings.exchange_audit.apply_unavailable", reason: issue_label(candidate[:unsupported_reason]))
        end
      end
    end
  end

  def receiver_candidate_selector(row)
    div(class: "rounded-xl border border-sky-200 bg-sky-50 p-3 dark:border-sky-500/40 dark:bg-sky-950/30") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-sky-700 dark:text-sky-200") { I18n.t("settings.exchange_audit.receiver_selection.title") }
      p(class: "mt-1 text-xs text-sky-900 dark:text-sky-100") { I18n.t("settings.exchange_audit.receiver_selection.description") }

      form(action: exchange_audit_admin_settings_path, method: "get", class: "mt-3 space-y-3") do
        preserved_connected_user_scope
        preserved_middle_overrides(except_source_transaction_id: nil)
        preserved_receiver_overrides(except_source_transaction_id: row.dig(:source, :id))

        select(
          name: "receiver_overrides[#{row.dig(:source, :id)}]",
          class: audit_select_class("sky")
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

  def audit_select_class(colour)
    border_class = colour == "indigo" ? "border-indigo-300 dark:border-indigo-500/50" : "border-sky-300 dark:border-sky-500/50"

    "w-full rounded-lg border #{border_class} bg-white px-3 py-2 text-sm text-slate-900 dark:bg-slate-900 dark:text-slate-100"
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

  def connection_button_class(connection)
    selected = connection[:connected_user_id] == selected_connection&.dig(:connected_user_id)
    base = "rounded-full px-3 py-2 text-sm font-semibold transition-colors"

    return "#{base} bg-indigo-600 text-white hover:bg-indigo-700" if selected

    "#{base} bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
  end

  def connection_button_label(connection)
    "#{connection.dig(:user, :first_name)} (#{connection[:pending_count]}/#{connection[:row_count]})"
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

  def preserved_connected_user_scope
    return if selected_connected_user_id.blank?

    input(type: "hidden", name: "connected_user_id", value: selected_connected_user_id)
  end

  def selected_connection
    @selected_connection ||= connections.find { |connection| connection[:connected_user_id] == selected_connected_user_id } || connections.first
  end

  def summary_stat(label, value)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 text-sm font-semibold text-slate-900 dark:text-slate-100") { value.to_s }
    end
  end

  def mapping_card(title:, values:)
    div(class: "rounded-xl border border-slate-200 bg-slate-50 px-3 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-[11px] font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { title }
      p(class: "mt-1 text-sm text-slate-900 dark:text-slate-100") { format_list(values) }
    end
  end
end
