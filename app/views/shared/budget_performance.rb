# frozen_string_literal: true

class Views::Shared::BudgetPerformance < Views::Base
  attr_reader :budget, :url

  def initialize(budget:, url:)
    @budget = budget
    @url = url
  end

  def view_template
    div(
      id: "budget_#{budget.id}_performance",
      class: "min-h-72",
      aria: { busy: "true" },
      data: {
        controller: "budget-performance",
        budget_performance_url_value: url,
        budget_performance_locale_value: I18n.locale.to_s,
        budget_performance_currency_value: "BRL",
        budget_performance_labels_value: labels.to_json
      }
    ) do
      loading_state
      error_state
      report_content
    end
  end

  private

  def loading_state
    div(
      class: "flex min-h-64 items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white/70 px-4 text-sm text-slate-500 " \
             "dark:border-slate-700 dark:bg-slate-900/70 dark:text-slate-400",
      role: :status,
      data: { budget_performance_target: "loadingState" }
    ) { translate(:loading) }
  end

  def error_state
    div(
      class: "hidden min-h-64 flex-col items-center justify-center gap-3 rounded-2xl border border-rose-200 bg-rose-50 px-4 text-center " \
             "dark:border-rose-900/60 dark:bg-rose-950/30",
      role: :alert,
      data: { budget_performance_target: "errorState" }
    ) do
      p(class: "text-sm font-semibold text-rose-700 dark:text-rose-300", data: { budget_performance_target: "errorMessage" }) { translate(:error) }
      button(
        type: :button,
        class: "rounded-lg border border-rose-300 bg-white px-3 py-2 text-sm font-semibold text-rose-700 hover:bg-rose-100 " \
               "dark:border-rose-800 dark:bg-slate-900 dark:text-rose-300 dark:hover:bg-rose-950/50",
        data: { action: "budget-performance#retry" }
      ) { translate(:retry) }
    end
  end

  def report_content
    div(class: "hidden space-y-5", data: { budget_performance_target: "content" }) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6") do
        metric_card(:definition, "definition")
        metric_card(:actual, "actual")
        metric_card(:remaining, "remaining")
        metric_card(:utilization, "utilization")
        metric_card(:period_completion, "periodCompletion")
        metric_card(:status, "status")
      end

      progress_section
      rule_section
      source_section
    end
  end

  def metric_card(label, target)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") { translate(label) }
      p(class: "mt-2 text-xl font-bold text-slate-950 dark:text-slate-100", data: { budget_performance_target: target }) { "—" }
    end
  end

  def progress_section
    div(class: "grid gap-3 lg:grid-cols-2") do
      progress_card(:utilization, "utilizationBar", "utilizationProgress")
      progress_card(:period_completion, "periodCompletionBar", "periodCompletionProgress")
    end
  end

  def progress_card(label, bar_target, progress_target)
    div(class: "rounded-2xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-xs font-black uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400") { translate(label) }
      div(
        class: "mt-3 h-2.5 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-800",
        role: :progressbar,
        aria: { label: translate(label), valuemin: 0, valuemax: 100, valuenow: 0 },
        data: { budget_performance_target: progress_target }
      ) do
        div(class: "h-full w-0 rounded-full bg-sky-600 transition-[width]", data: { budget_performance_target: bar_target })
      end
    end
  end

  def rule_section
    section(aria: { labelledby: "budget_#{budget.id}_performance_rules" }) do
      h3(id: "budget_#{budget.id}_performance_rules", class: heading_class) { translate(:rules) }
      div(class: "mt-3 grid gap-3 md:grid-cols-2", data: { budget_performance_target: "rules" })
    end
  end

  def source_section
    section(aria: { labelledby: "budget_#{budget.id}_performance_sources" }) do
      h3(id: "budget_#{budget.id}_performance_sources", class: heading_class) { translate(:sources) }
      div(class: "mt-3 grid gap-3 md:grid-cols-2", data: { budget_performance_target: "sources" })
    end
  end

  def labels
    %i[
      definition actual remaining utilization period_completion status available exact exceeded rules sources cash card source_count no_sources chunk error
      inclusive_true inclusive_false first_installment_only_true first_installment_only_false current_limit recorded_remaining
    ].index_with { |key| translate(key) }.merge(locale: I18n.locale.to_s)
  end

  def heading_class
    "text-xs font-black uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400"
  end

  def translate(key)
    I18n.t("reports.budget_performance.#{key}")
  end
end
