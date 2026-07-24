# frozen_string_literal: true

class Views::HealthCheck::RepairPreviews::Show < Views::Base
  include TranslateHelper
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :definition, :entry, :preview, :workspace_scope

  def initialize(entry:, definition:, preview:, workspace_scope:)
    @entry = entry
    @definition = definition
    @preview = preview
    @workspace_scope = workspace_scope
  end

  def view_template
    turbo_frame_tag "center_container" do
      main(class: "mx-auto w-full max-w-6xl px-3 py-4 sm:px-5") do
        header_section
        scope_section
        state_section
        changes_section
        references_section if preview.references.present?
        warnings_section if preview.warnings.present?
        paid_history_section if preview.paid_history.present?
        digest_section
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-4 border-b border-slate-200 pb-5 sm:flex-row sm:items-start sm:justify-between dark:border-slate-700") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-sky-700 dark:text-sky-300") { I18n.t("health_check.repairs.preview.eyebrow") }
        h1(class: "mt-1 wrap-break-word text-2xl font-bold text-slate-950 dark:text-slate-100") { I18n.t(definition.title_key) }
        p(class: "mt-2 text-sm text-slate-600 dark:text-slate-400") do
          I18n.t("health_check.repairs.preview.description", check: I18n.t(entry.title_key), finding_id: preview.finding_id)
        end
      end

      link_to(
        I18n.t("health_check.repairs.preview.back"),
        healthcheck_check_path(entry.key, **workspace_scope_query),
        class: secondary_button_class,
        data: { turbo_frame: "center_container", turbo_prefetch: false }
      )
    end
  end

  def scope_section
    section(class: panel_class("mt-5")) do
      dl(class: "grid gap-3 sm:grid-cols-2 lg:grid-cols-4") do
        metadata(I18n.t("health_check.scope.administrator"), preview.scope.user.full_name)
        metadata(I18n.t("health_check.scope.context"), preview.scope.context.name)
        metadata(I18n.t("health_check.repairs.preview.finding"), "##{preview.finding_id}")
        metadata(I18n.t("health_check.repairs.preview.state"), I18n.t("health_check.repairs.states.#{preview.state}"))
      end
    end
  end

  def state_section
    section(id: "health_check_repair_preview_state", class: state_panel_class) do
      h2(class: "font-bold") { I18n.t("health_check.repairs.states.#{preview.state}") }
      p(class: "mt-2 text-sm") { state_description }
      if preview.unavailable_reason.present?
        p(class: "mt-2 text-sm font-semibold") do
          I18n.t(
            "health_check.details.unavailable_reasons.#{preview.unavailable_reason}",
            default: I18n.t("health_check.details.unavailable_reasons.diagnostic_only")
          )
        end
      end
    end
  end

  def changes_section
    section(class: "mt-5") do
      h2(class: section_title_class) { I18n.t("health_check.repairs.preview.changes") }
      if preview.changes.empty?
        p(class: "#{panel_class('mt-3')} text-sm text-slate-600 dark:text-slate-400") { I18n.t("health_check.repairs.preview.no_changes") }
      else
        div(id: "health_check_repair_preview_changes", class: "mt-3 space-y-3") do
          preview.changes.each { |change| change_card(change) }
        end
      end
    end
  end

  def change_card(change)
    article(class: panel_class) do
      div(class: "flex flex-wrap items-center justify-between gap-2 border-b border-slate-200 pb-3 dark:border-slate-700") do
        h3(class: "text-sm font-bold text-slate-950 dark:text-slate-100") { "#{change.record_type} ##{change.record_id}" }
        code(class: "rounded bg-slate-100 px-2 py-1 text-xs text-slate-700 dark:bg-slate-800 dark:text-slate-200") { change.attribute }
      end
      dl(class: "mt-3 grid gap-3 sm:grid-cols-2") do
        value_block(I18n.t("health_check.repairs.preview.before"), change.before, tone: "before")
        value_block(I18n.t("health_check.repairs.preview.after"), change.after, tone: "after")
      end
    end
  end

  def value_block(label, value, tone:)
    classes = tone == "after" ? "bg-emerald-50 dark:bg-emerald-950/30" : "bg-slate-50 dark:bg-slate-950"
    div(class: "rounded-md p-3 #{classes}") do
      dt(class: "text-2xs font-semibold uppercase tracking-[0.1em] text-slate-500 dark:text-slate-400") { label }
      dd(class: "mt-1 wrap-break-word text-sm font-semibold text-slate-950 dark:text-slate-100") { display_value(value) }
    end
  end

  def references_section
    list_section(
      title: I18n.t("health_check.repairs.preview.references"),
      id: "health_check_repair_preview_references",
      entries: preview.references
    )
  end

  def warnings_section
    list_section(
      title: I18n.t("health_check.repairs.preview.warnings"),
      id: "health_check_repair_preview_warnings",
      entries: preview.warnings,
      warning: true
    )
  end

  def paid_history_section
    section(id: "health_check_repair_preview_paid_history", class: panel_class("mt-5")) do
      h2(class: section_title_class) { I18n.t("health_check.repairs.preview.paid_history") }
      p(class: "mt-2 text-sm text-slate-600 dark:text-slate-300") { display_value(preview.paid_history) }
    end
  end

  def list_section(title:, id:, entries:, warning: false)
    section(id:, class: panel_class("mt-5")) do
      h2(class: section_title_class) { title }
      ul(class: "mt-3 space-y-2") do
        Array(entries).each do |entry|
          li(class: "rounded-md px-3 py-2 text-sm #{warning ? warning_item_class : 'bg-slate-50 text-slate-700 dark:bg-slate-950 dark:text-slate-200'}") do
            display_value(entry)
          end
        end
      end
    end
  end

  def digest_section
    section(id: "health_check_repair_preview_digest", class: panel_class("mt-5")) do
      h2(class: section_title_class) { I18n.t("health_check.repairs.preview.digest") }
      code(class: "mt-2 block break-all rounded-md bg-slate-950 px-3 py-2 text-xs text-slate-100") { preview.digest }
      input(type: "hidden", id: "health_check_repair_apply_token", name: "apply_token", value: preview.apply_token)
      p(class: "mt-2 text-xs text-slate-500 dark:text-slate-400") { I18n.t("health_check.repairs.preview.token_notice") }
    end
  end

  def display_value(value)
    case value
    when Hash
      value.map { |key, nested| "#{key.to_s.humanize}: #{display_value(nested)}" }.join(" · ")
    when Array
      value.map { |nested| display_value(nested) }.join(", ")
    when nil
      I18n.t("health_check.values.no_value")
    else
      value.to_s
    end
  end

  def metadata(label, value)
    div(class: "min-w-0") do
      dt(class: "text-2xs font-semibold uppercase tracking-[0.1em] text-slate-500 dark:text-slate-400") { label }
      dd(class: "mt-1 wrap-break-word text-sm font-semibold text-slate-900 dark:text-slate-100") { value }
    end
  end

  def state_description
    I18n.t("health_check.repairs.preview.state_descriptions.#{preview.state}")
  end

  def workspace_scope_query
    return {} if workspace_scope.all_connections?

    { connected_user_id: workspace_scope.connected_user.id }
  end

  def state_panel_class
    base = "mt-5 rounded-lg border px-4 py-4"
    return "#{base} border-emerald-300 bg-emerald-50 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100" if preview.previewable?

    "#{base} border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100"
  end

  def panel_class(prefix = nil)
    "#{prefix} rounded-lg border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-900".strip
  end

  def section_title_class
    "text-base font-bold text-slate-950 dark:text-slate-100"
  end

  def warning_item_class
    "bg-amber-50 text-amber-900 dark:bg-amber-950/40 dark:text-amber-200"
  end

  def secondary_button_class
    "inline-flex min-h-10 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-bold text-slate-700 " \
      "hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
