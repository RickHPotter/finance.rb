# frozen_string_literal: true

class Views::HealthCheck::Checks::FindingBase < Views::Base
  include TranslateHelper

  attr_reader :entry, :row, :workspace_scope

  def initialize(row:, entry:, workspace_scope:)
    @row = row
    @entry = entry
    @workspace_scope = workspace_scope
  end

  private

  def finding_shell(title:, subtitle: nil, href: nil, &)
    article(class: "overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm dark:border-slate-700 dark:bg-slate-900 dark:shadow-none") do
      div(class: finding_header_class) do
        div(class: "min-w-0") do
          h2(class: "wrap-break-word text-base font-bold text-slate-950 dark:text-slate-100") { title }
          p(class: "mt-1 text-xs text-slate-600 dark:text-slate-400") { subtitle } if subtitle.present?
        end

        div(class: "flex shrink-0 flex-wrap items-center gap-2") do
          capability_controls
          a(href:, class: open_link_class, data: { turbo_frame: "_top" }) { I18n.t("health_check.details.open_record") } if href.present?
        end
      end

      yield
    end
  end

  def issue_chips(issues, warnings: [])
    div(class: "flex flex-wrap gap-2") do
      Array(issues).each { |issue| issue_chip(issue, warning: false) }
      Array(warnings).each { |warning| issue_chip(warning, warning: true) }
    end
  end

  def issue_chip(code, warning:)
    classes = if warning
                "border-amber-300 bg-amber-50 text-amber-800 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-200"
              else
                "border-rose-300 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/40 dark:text-rose-200"
              end

    span(class: "rounded-full border px-2.5 py-1 text-xs font-semibold #{classes}") { issue_label(code) }
  end

  def issue_label(code)
    I18n.t(issue_translation_key(code), default: code.to_s.humanize)
  end

  def issue_translation_key(code)
    "health_check.details.issues.#{code}"
  end

  def metric(label, value)
    div(class: "min-w-0 rounded-md bg-slate-50 px-3 py-2 dark:bg-slate-950") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.1em] text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 wrap-break-word text-sm font-bold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def money(value)
    return I18n.t("health_check.values.no_value") if value.nil?

    from_cent_based_to_float(value, "R$")
  end

  def formatted_date(value)
    return I18n.t("health_check.values.no_value") if value.blank?

    I18n.l(value.to_date, format: :short)
  end

  def capability_controls
    capability_badge
    preview_actions.each { |action| preview_link(action) }
  end

  def capability_badge
    repairable = row.dig(:health_check, :repairable)
    key = repairable ? "repairable" : "read_only"
    classes = if repairable
                "border-sky-300 bg-sky-50 text-sky-800 dark:border-sky-800 dark:bg-sky-950/40 dark:text-sky-200"
              else
                "border-slate-300 bg-slate-100 text-slate-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
              end

    span(class: "rounded-full border px-2.5 py-1 text-xs font-bold #{classes}") { I18n.t("health_check.details.capabilities.#{key}") }
  end

  def preview_actions
    Array(row.dig(:health_check, :preview_actions))
  end

  def preview_link(action)
    repair_key = entry.repair_keys.first
    query = action.symbolize_keys
    query[:connected_user_id] = workspace_scope.connected_user.id unless workspace_scope.all_connections?
    strategy = action[:strategy] || action["strategy"]
    label_key = strategy.present? ? "health_check.repairs.actions.#{strategy}" : "health_check.repairs.actions.preview"

    a(
      href: healthcheck_repair_preview_path(entry.key, repair_key, **query),
      class: preview_link_class,
      data: { turbo_method: :post, turbo_frame: "center_container", turbo_prefetch: false }
    ) { I18n.t(label_key) }
  end

  def capability_reason
    reason = row.dig(:health_check, :unavailable_reason)
    return if reason.blank?

    p(class: "mt-3 text-xs font-medium text-slate-500 dark:text-slate-400") do
      I18n.t("health_check.details.unavailable_reasons.#{reason}", default: I18n.t("health_check.details.unavailable_reasons.diagnostic_only"))
    end
  end

  def open_link_class
    "inline-flex min-h-8 items-center justify-center rounded-md border border-slate-300 px-2.5 py-1 text-xs font-bold text-slate-700 " \
      "hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
  end

  def preview_link_class
    "inline-flex min-h-8 items-center justify-center rounded-md border border-sky-700 bg-sky-700 px-2.5 py-1 text-xs font-bold text-white " \
      "hover:bg-sky-800 dark:border-sky-500 dark:bg-sky-600 dark:hover:bg-sky-500"
  end

  def finding_header_class
    "flex flex-col gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3 sm:flex-row sm:items-start sm:justify-between " \
      "dark:border-slate-700 dark:bg-slate-950"
  end
end
