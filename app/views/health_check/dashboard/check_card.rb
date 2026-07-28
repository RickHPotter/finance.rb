# frozen_string_literal: true

class Views::HealthCheck::Dashboard::CheckCard < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  COUNT_KEYS = %w[affected failures warnings repairable read_only].freeze

  attr_reader :scope, :summary

  def initialize(summary:, scope:)
    @summary = summary
    @scope = scope
  end

  def view_template
    article(
      id: "health_check_check_#{summary.entry.key}",
      class: "flex min-w-0 flex-col rounded-lg border border-slate-200 bg-white p-3 shadow-sm dark:border-slate-700 dark:bg-slate-900 dark:shadow-none"
    ) do
      card_header
      card_reason
      counts
      metadata
    end
  end

  private

  def card_header
    div(class: "flex items-start justify-between gap-3") do
      div(class: "min-w-0") do
        h3(class: "wrap-break-word text-base font-bold text-slate-950 dark:text-slate-100") { I18n.t(summary.entry.title_key) }
        p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t(summary.entry.description_key) }
      end

      span(
        id: "health_check_status_#{summary.entry.key}",
        class: "shrink-0 rounded-full border px-2.5 py-1 text-xs font-bold #{status_badge_class}"
      ) { I18n.t("health_check.states.#{summary.status}") }
    end
  end

  def card_reason
    return if summary.reason_code.blank?

    p(
      id: "health_check_reason_#{summary.entry.key}",
      class: "mt-3 rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-700 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-300"
    ) { localized_reason }
  end

  def counts
    dl(class: "mt-3 grid grid-cols-2 gap-2 sm:grid-cols-5") do
      COUNT_KEYS.each do |key|
        div(class: "rounded-md bg-slate-50 px-2.5 py-2 dark:bg-slate-950") do
          dt(class: "text-2xs font-semibold uppercase tracking-[0.1em] text-slate-500 dark:text-slate-400") do
            I18n.t("health_check.fields.#{key}")
          end
          dd(class: "mt-1 text-sm font-bold text-slate-950 dark:text-slate-100") { summary.count(key) }
        end
      end
    end
  end

  def metadata
    div(class: "mt-3 grid gap-2 border-t border-slate-200 pt-2 text-xs sm:grid-cols-3 dark:border-slate-700") do
      metadata_value(I18n.t("health_check.fields.scope"), I18n.t("health_check.scopes.#{summary.entry.scope_kind}"))
      metadata_value(I18n.t("health_check.fields.last_run"), last_run_label)
      metadata_value(I18n.t("health_check.fields.duration"), duration_label)
    end

    div(class: "mt-2 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between") do
      p(class: "text-xs font-semibold text-slate-500 dark:text-slate-400") do
        summary.entry.repairable? ? I18n.t("health_check.values.repair_available") : I18n.t("health_check.values.diagnostic_only")
      end
      div(class: "flex flex-wrap gap-2") do
        details_action
        run_action
      end
    end
  end

  def details_action
    link_to(
      I18n.t("health_check.actions.details"),
      healthcheck_check_path(summary.entry.key, **scope_query),
      class: run_button_class,
      data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
    )
  end

  def run_action
    if summary.status == "running"
      span(class: "#{run_button_class} cursor-not-allowed opacity-60", aria: { disabled: true }) do
        I18n.t("health_check.actions.running")
      end
    else
      label = summary.never_run? ? I18n.t("health_check.actions.run") : I18n.t("health_check.actions.rerun")
      link_to(
        label,
        healthcheck_check_run_path(summary.entry.key, **scope_query),
        class: run_button_class,
        data: { turbo_method: :post, turbo_frame: "center_container", turbo_prefetch: false }
      )
    end
  end

  def scope_query
    return {} if scope.all_connections?

    { connected_user_id: scope.connected_user.id }
  end

  def metadata_value(label, value)
    div(class: "min-w-0") do
      p(class: "font-semibold uppercase tracking-[0.1em] text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 wrap-break-word font-medium text-slate-800 dark:text-slate-200") { value }
    end
  end

  def localized_reason
    I18n.t(
      "health_check.reasons.#{summary.reason_code}",
      default: I18n.t("health_check.reasons.unavailable")
    )
  end

  def last_run_label
    return I18n.t("health_check.values.no_value") if summary.last_run_at.blank?

    I18n.l(summary.last_run_at, format: :shorter)
  end

  def duration_label
    return I18n.t("health_check.values.no_value") if summary.run&.duration_ms.blank?

    I18n.t("health_check.values.milliseconds", count: summary.run.duration_ms)
  end

  def status_badge_class
    {
      "healthy" => "border-emerald-300 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-200",
      "warning" => "border-amber-300 bg-amber-50 text-amber-800 dark:border-amber-800 dark:bg-amber-950/50 dark:text-amber-200",
      "failing" => "border-rose-300 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/50 dark:text-rose-200",
      "running" => "border-sky-300 bg-sky-50 text-sky-800 dark:border-sky-800 dark:bg-sky-950/50 dark:text-sky-200",
      "unavailable" => "border-slate-300 bg-slate-100 text-slate-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
    }.fetch(summary.status)
  end

  def run_button_class
    "inline-flex min-h-9 shrink-0 items-center justify-center rounded-md border border-slate-300 px-3 py-1.5 text-xs font-bold text-slate-700 " \
      "transition hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
