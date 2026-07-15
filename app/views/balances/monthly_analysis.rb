# frozen_string_literal: true

class Views::Balances::MonthlyAnalysis < Views::Base
  def view_template
    turbo_frame_tag :balances_monthly_analysis_content do
      section(class: "space-y-2", aria: { labelledby: "balances_monthly_analysis_title" }) do
        h2(id: "balances_monthly_analysis_title", class: "text-base font-semibold text-stone-900 dark:text-slate-100") do
          I18n.t("balances.monthly_analysis.title")
        end
        p(class: "text-sm text-stone-600 dark:text-slate-400") { I18n.t("balances.monthly_analysis.subtitle") }
        p(class: "py-8 text-center text-sm text-stone-500 dark:text-slate-400") { I18n.t("balances.monthly_analysis.preparing") }
      end
    end
  end
end
