# frozen_string_literal: true

class Views::HealthCheck::Dashboard::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  attr_reader :scope, :summaries

  def initialize(scope:, summaries:)
    @scope = scope
    @summaries = summaries
  end

  def view_template
    turbo_frame_tag :center_container do
      main(class: "#{compact_crud_shell_class} overflow-hidden") do
        turbo_stream_from HealthCheck::Stream.for(scope)
        header_section
        div(class: "px-3 md:px-4") do
          render Views::HealthCheck::Dashboard::Overview.new(scope:, summaries:)
          financial_integrity_section
          render Views::HealthCheck::Dashboard::Maintenance.new
        end
      end
    end
  end

  private

  def header_section
    header(class: "#{compact_crud_header_class} gap-3") do
      div(class: "flex min-w-0 flex-col items-start") do
        h1(class: compact_crud_title_class) { I18n.t("health_check.title") }
        render_scenario_badge
      end
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
end
