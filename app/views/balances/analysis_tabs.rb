# frozen_string_literal: true

module Views::Balances::AnalysisTabs
  private

  def render_analysis_tabs
    div(class: "mb-5 flex gap-2 overflow-x-auto border-b border-stone-200 px-4 pb-3 dark:border-slate-700", role: :tablist) do
      analysis_tab_button("overview", I18n.t("balances.monthly_analysis.overview"), selected: true)
      analysis_tab_button("monthly_analysis", I18n.t("balances.monthly_analysis.title"))
    end
  end

  def analysis_tab_button(name, label, selected: false)
    button(
      type: :button,
      role: :tab,
      aria: { selected: selected.to_s, controls: "balances_#{name}_panel" },
      tabindex: selected ? 0 : -1,
      class: "shrink-0 rounded-full bg-gray-200 px-3 py-1 text-sm font-semibold text-gray-700 transition-colors dark:bg-slate-800 dark:text-slate-200",
      data: { action: "click->naming-tabs#select", naming_tabs_target: "tab", naming_tabs_name: name }
    ) { label }
  end

  def analysis_loading_state
    div(class: "rounded-lg border border-dashed border-stone-300 bg-stone-50 px-4 py-8 text-center text-sm text-stone-500 " \
               "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-400") do
      I18n.t("balances.monthly_analysis.loading")
    end
  end
end
