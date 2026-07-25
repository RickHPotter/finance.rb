# frozen_string_literal: true

class Views::HealthCheck::Dashboard::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TurboStreamFrom

  attr_reader :scope, :summaries

  def initialize(scope:, summaries:)
    @scope = scope
    @summaries = summaries
  end

  def view_template
    turbo_frame_tag :center_container do
      main(class: "w-full px-2 py-2 sm:px-3") do
        turbo_stream_from HealthCheck::Stream.for(scope)
        header_section
        render Views::HealthCheck::Dashboard::Overview.new(scope:, summaries:)
        financial_integrity_section
        render Views::HealthCheck::Dashboard::Maintenance.new
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-3 border-b border-slate-200 pb-3 sm:flex-row sm:items-start sm:justify-between dark:border-slate-700") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-sky-700 dark:text-sky-300") { I18n.t("health_check.title") }
        h1(class: "mt-1 text-2xl font-bold text-slate-950 dark:text-slate-100") { I18n.t("health_check.title") }
        render_scenario_badge
        p(class: "mt-2 max-w-3xl text-sm text-slate-600 dark:text-slate-400") { I18n.t("health_check.description") }
      end

      link_to(
        I18n.t("health_check.history.action"),
        audit_operations_path,
        class: history_link_class,
        data: { turbo_frame: "_top", turbo_prefetch: false }
      )
    end
  end

  def financial_integrity_section
    section(aria: { labelledby: "health_check_financial_integrity_title" }, class: "border-b border-slate-200 py-4 dark:border-slate-700") do
      h2(id: "health_check_financial_integrity_title", class: "text-lg font-bold text-slate-950 dark:text-slate-100") do
        I18n.t("health_check.groups.financial_integrity.title")
      end
      p(class: "mt-1 max-w-3xl text-sm text-slate-600 dark:text-slate-400") do
        I18n.t("health_check.groups.financial_integrity.description")
      end

      div(class: "mt-3 grid gap-3 lg:grid-cols-2") do
        summaries.each do |summary|
          render Views::HealthCheck::Dashboard::CheckCard.new(summary:, scope:)
        end
      end
    end
  end

  def history_link_class
    "inline-flex min-h-10 shrink-0 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 " \
      "hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
