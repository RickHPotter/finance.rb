# frozen_string_literal: true

class Views::Budgets::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :budget

  def initialize(budget:)
    @budget = budget
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "min-h-[calc(100svh-12rem)] rounded-3xl border border-slate-200 bg-white p-4 shadow-sm sm:p-6") do
        dashboard_header
        placeholder_grid
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-4 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div do
        p(class: "text-xs font-semibold uppercase tracking-[0.22em] text-slate-500") { action_model(:analyse, Budget) }
        h1(class: "mt-2 text-3xl font-black tracking-tight text-slate-950") { budget.description }
        render_scenario_badge
        p(class: "mt-3 max-w-3xl text-sm text-slate-600") do
          I18n.t("dashboards.budgets.placeholder")
        end
      end

      div(class: "flex flex-wrap gap-2") do
        link_to(action_model(:edit, Budget), edit_budget_path(budget),
                class: "rounded-full border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-100",
                data: { turbo_frame: "_top", turbo_prefetch: false })
        link_to(action_model(:index, Budget, 2), budgets_path,
                class: "rounded-full bg-slate-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-slate-700",
                data: { turbo_frame: "_top", turbo_prefetch: false })
      end
    end
  end

  def placeholder_grid
    div(class: "mt-6 grid gap-3 md:grid-cols-3") do
      dashboard_stat(model_attribute(Budget, :value), from_cent_based_to_float(budget.value, "R$"))
      dashboard_stat(model_attribute(Budget, :remaining_value), from_cent_based_to_float(budget.remaining_value, "R$"))
      dashboard_stat(model_attribute(Budget, :month_year), I18n.l(Date.new(budget.year, budget.month, 1), format: "%B %Y"))
    end
  end

  def dashboard_stat(label, value)
    div(class: "rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3") do
      p(class: "text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "mt-2 text-lg font-bold text-slate-950") { value.to_s }
    end
  end
end
