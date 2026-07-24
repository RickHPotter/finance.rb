# frozen_string_literal: true

class Views::HealthCheck::Dashboard::Overview < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :scope, :summaries

  def initialize(scope:, summaries:)
    @scope = scope
    @summaries = summaries
  end

  def view_template
    section(
      id: "health_check_overview",
      aria: { labelledby: "health_check_overview_title" },
      class: "border-b border-slate-200 py-6 dark:border-slate-700"
    ) do
      div(class: "flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between") do
        div(class: "flex flex-col gap-1") do
          h2(id: "health_check_overview_title", class: "text-lg font-bold text-slate-950 dark:text-slate-100") do
            I18n.t("health_check.overview.title")
          end
          p(class: "max-w-3xl text-sm text-slate-600 dark:text-slate-400") { I18n.t("health_check.overview.description") }
        end

        run_all_action
      end

      div(class: "mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-5") do
        HealthCheck::DashboardSummary::DISPLAY_STATES.each { |state| status_total(state) }
      end

      scope_summary
    end
  end

  private

  def status_total(state)
    div(
      id: "health_check_overview_#{state}",
      class: "rounded-lg border px-3 py-3 #{status_panel_class(state)}"
    ) do
      p(class: "text-xs font-semibold uppercase tracking-[0.12em]") { I18n.t("health_check.states.#{state}") }
      p(class: "mt-1 text-2xl font-bold") { summaries.count { |summary| summary.status == state } }
    end
  end

  def scope_summary
    div(class: "mt-4 rounded-lg border border-slate-200 bg-slate-50 p-4 dark:border-slate-700 dark:bg-slate-900") do
      h3(class: "text-sm font-bold text-slate-950 dark:text-slate-100") { I18n.t("health_check.scope.title") }
      dl(class: "mt-3 grid gap-3 sm:grid-cols-3") do
        scope_value(I18n.t("health_check.scope.administrator"), scope.user.full_name)
        scope_value(I18n.t("health_check.scope.context"), scope.context.name)
        scope_value(I18n.t("health_check.scope.connections"), connection_label)
      end
    end
  end

  def run_all_action
    if summaries.all? { |summary| summary.status == "running" }
      span(class: "#{run_button_class} cursor-not-allowed opacity-60", aria: { disabled: true }) do
        I18n.t("health_check.actions.running_all")
      end
    else
      link_to(
        I18n.t("health_check.actions.run_all"),
        healthcheck_runs_path(**scope_query),
        class: run_button_class,
        data: { turbo_method: :post, turbo_frame: "center_container", turbo_prefetch: false }
      )
    end
  end

  def connection_label
    return I18n.t("health_check.scope.all_connections") if scope.all_connections?

    scope.connected_user.full_name
  end

  def scope_query
    return {} if scope.all_connections?

    { connected_user_id: scope.connected_user.id }
  end

  def scope_value(label, value)
    div do
      dt(class: "text-xs font-semibold uppercase tracking-[0.12em] text-slate-500 dark:text-slate-400") { label }
      dd(class: "mt-1 wrap-break-word text-sm font-semibold text-slate-950 dark:text-slate-100") { value }
    end
  end

  def status_panel_class(state)
    {
      "healthy" => "border-emerald-200 bg-emerald-50 text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-200",
      "warning" => "border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-200",
      "failing" => "border-rose-200 bg-rose-50 text-rose-900 dark:border-rose-900 dark:bg-rose-950/40 dark:text-rose-200",
      "running" => "border-sky-200 bg-sky-50 text-sky-900 dark:border-sky-900 dark:bg-sky-950/40 dark:text-sky-200",
      "unavailable" => "border-slate-200 bg-slate-100 text-slate-800 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200"
    }.fetch(state)
  end

  def run_button_class
    "inline-flex min-h-10 shrink-0 items-center justify-center rounded-md border border-sky-700 bg-sky-600 px-4 py-2 text-sm font-bold text-white " \
      "shadow-sm transition hover:border-sky-600 hover:bg-sky-700 dark:border-sky-500 dark:bg-sky-700 dark:hover:bg-sky-600"
  end
end
