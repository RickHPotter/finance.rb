# frozen_string_literal: true

class Views::Balances::MonthlyAnalysis < Views::Base
  def view_template
    turbo_frame_tag :balances_monthly_analysis_content do
      section(
        class: "min-h-[36rem] space-y-6",
        aria: { labelledby: "balances_monthly_analysis_title" },
        data: controller_data
      ) do
        render_header
        render_loading_state
        render_error_state
        render_empty_state

        div(class: "hidden space-y-6", data: { balances_monthly_analysis_target: "content" }) do
          render_summary
          render_breakdowns
          render_transfers
          render_piggy_banks
        end
      end
    end
  end

  private

  def controller_data
    {
      controller: "balances-monthly-analysis",
      balances_monthly_analysis_url_value: monthly_analysis_json_balances_path(format: :json),
      balances_monthly_analysis_locale_value: I18n.locale.to_s,
      balances_monthly_analysis_currency_value: "BRL",
      balances_monthly_analysis_labels_value: labels.to_json
    }
  end

  def render_header
    div(class: "flex flex-col gap-4 border-b border-stone-200 pb-5 sm:flex-row sm:items-end sm:justify-between dark:border-slate-700") do
      div(class: "min-w-0") do
        h2(id: "balances_monthly_analysis_title", class: "text-base font-semibold text-stone-900 dark:text-slate-100") do
          I18n.t("balances.monthly_analysis.title")
        end
        p(class: "mt-1 max-w-3xl text-sm text-stone-600 dark:text-slate-400") { I18n.t("balances.monthly_analysis.subtitle") }
      end

      div(class: "flex w-full items-center justify-between gap-2 sm:w-auto sm:justify-end") do
        month_button(:previous)
        input(
          id: "balances_monthly_analysis_month",
          type: :month,
          value: Time.zone.today.strftime("%Y-%m"),
          aria: { label: I18n.t("balances.monthly_analysis.title") },
          class: "min-w-0 flex-1 rounded-lg border border-stone-300 bg-white px-3 py-2 text-sm font-medium text-stone-800 sm:w-40 " \
                 "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100",
          data: {
            balances_monthly_analysis_target: "monthInput",
            action: "change->balances-monthly-analysis#changeMonth"
          }
        )
        month_button(:next)
      end
    end
  end

  def month_button(direction)
    action = direction == :previous ? "previousMonth" : "nextMonth"
    attributes = {
      name: "#{direction}-month",
      aria_label: I18n.t("balances.monthly_analysis.#{direction}_month"),
      class: "relative left-auto right-auto inline-flex size-10 shrink-0 items-center justify-center rounded-lg border border-stone-300 bg-white " \
             "text-stone-700 opacity-100 transition " \
             "hover:bg-stone-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-600 dark:border-slate-600 dark:bg-slate-900 " \
             "dark:text-slate-200 dark:hover:bg-slate-800",
      data_action: "click->balances-monthly-analysis##{action}"
    }

    direction == :previous ? CalendarPrev(**attributes) : CalendarNext(**attributes)
  end

  def render_loading_state
    div(
      class: "flex min-h-96 items-center justify-center text-sm font-medium text-stone-500 dark:text-slate-400",
      role: :status,
      data: { balances_monthly_analysis_target: "loadingState" }
    ) { I18n.t("balances.monthly_analysis.loading") }
  end

  def render_error_state
    div(
      class: "hidden min-h-96 items-center justify-center",
      role: :alert,
      data: { balances_monthly_analysis_target: "errorState" }
    ) do
      div(class: "max-w-md text-center") do
        p(class: "text-sm font-semibold text-rose-700 dark:text-rose-300", data: { balances_monthly_analysis_target: "errorMessage" }) do
          I18n.t("balances.monthly_analysis.error")
        end
        Button(
          type: :button,
          variant: :outline,
          class: "mt-4",
          data: { action: "click->balances-monthly-analysis#retry" }
        ) { I18n.t("balances.monthly_analysis.retry") }
      end
    end
  end

  def render_empty_state
    div(
      class: "hidden min-h-96 items-center justify-center text-center text-sm text-stone-500 dark:text-slate-400",
      data: { balances_monthly_analysis_target: "emptyState" }
    ) { I18n.t("balances.monthly_analysis.empty") }
  end

  def render_summary
    div(class: "grid grid-cols-1 gap-2 sm:grid-cols-3") do
      summary_metric(I18n.t("balances.monthly_analysis.income"), "summaryIncome", "text-emerald-700 dark:text-emerald-300")
      summary_metric(I18n.t("balances.monthly_analysis.outcome"), "summaryOutcome", "text-rose-700 dark:text-rose-300")
      summary_metric(I18n.t("balances.monthly_analysis.net"), "summaryNet", "text-stone-900 dark:text-slate-100")
    end
  end

  def summary_metric(label, target, tone)
    div(class: "rounded-lg border border-stone-200 bg-stone-50 px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-xs font-semibold text-stone-500 dark:text-slate-400") { label }
      p(class: "mt-2 text-lg font-semibold #{tone}", data: { balances_monthly_analysis_target: target }) { "--" }
    end
  end

  def render_breakdowns
    div(class: "grid grid-cols-1 gap-3 lg:grid-cols-2") do
      breakdown_panel(I18n.t("balances.monthly_analysis.income_by_category"), "incomeCategories")
      breakdown_panel(I18n.t("balances.monthly_analysis.outcome_by_category"), "outcomeCategories")
      breakdown_panel(I18n.t("balances.monthly_analysis.income_by_entity"), "incomeEntities")
      breakdown_panel(I18n.t("balances.monthly_analysis.outcome_by_entity"), "outcomeEntities")
    end
  end

  def breakdown_panel(title, target_prefix)
    article(class: "min-w-0 rounded-lg border border-stone-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-950") do
      h3(class: "text-sm font-semibold text-stone-800 dark:text-slate-200") { title }
      div(class: "mt-3 h-56 w-full") do
        canvas(data: { balances_monthly_analysis_target: "#{target_prefix}Canvas" })
      end
      ol(class: "mt-3 space-y-2", data: { balances_monthly_analysis_target: "#{target_prefix}List" })
    end
  end

  def render_transfers
    section(class: "border-t border-stone-200 pt-5 dark:border-slate-700", aria: { labelledby: "monthly_analysis_transfers_title" }) do
      h3(id: "monthly_analysis_transfers_title", class: "text-sm font-semibold text-stone-900 dark:text-slate-100") do
        I18n.t("balances.monthly_analysis.transfers")
      end
      div(class: "mt-3 grid grid-cols-1 gap-3 lg:grid-cols-3") do
        activity_group(I18n.t("balances.monthly_analysis.sent"), "transferSent", "text-rose-700 dark:text-rose-300")
        activity_group(I18n.t("balances.monthly_analysis.received"), "transferReceived", "text-emerald-700 dark:text-emerald-300")
        activity_group(I18n.t("balances.monthly_analysis.failed"), "transferFailed", "text-amber-700 dark:text-amber-300")
      end
    end
  end

  def activity_group(label, target_prefix, tone)
    div(class: "min-w-0 rounded-lg border border-stone-200 p-4 dark:border-slate-700") do
      div(class: "flex items-baseline justify-between gap-3") do
        h4(class: "text-xs font-semibold text-stone-600 dark:text-slate-400") { label }
        p(class: "shrink-0 text-sm font-semibold #{tone}", data: { balances_monthly_analysis_target: "#{target_prefix}Total" }) { "--" }
      end
      ul(class: "mt-3 space-y-2", data: { balances_monthly_analysis_target: "#{target_prefix}List" })
    end
  end

  def render_piggy_banks
    section(class: "border-t border-stone-200 pt-5 dark:border-slate-700", aria: { labelledby: "monthly_analysis_piggy_banks_title" }) do
      h3(id: "monthly_analysis_piggy_banks_title", class: "text-sm font-semibold text-stone-900 dark:text-slate-100") do
        I18n.t("balances.monthly_analysis.piggy_banks")
      end
      div(class: "mt-3 grid grid-cols-2 gap-2 lg:grid-cols-5") do
        piggy_total("contributed", "piggyContributed")
        piggy_total("projected_contribution", "piggyProjectedContribution")
        piggy_total("withdrawn", "piggyWithdrawn")
        piggy_total("projected_withdrawal", "piggyProjectedWithdrawal")
        piggy_total("recognized_profit_loss", "piggyProfitLoss")
      end
      ul(class: "mt-3 space-y-3", data: { balances_monthly_analysis_target: "piggyGroupsList" })
    end
  end

  def piggy_total(key, target)
    projected_class = if key.to_s.start_with?("projected")
                        "border-dashed border-amber-400 bg-amber-50/60 dark:border-amber-700 dark:bg-amber-950/20"
                      else
                        "border-stone-200 dark:border-slate-700"
                      end

    div(class: "min-w-0 rounded-lg border px-3 py-3 #{projected_class}") do
      p(class: "text-xs font-semibold text-stone-500 dark:text-slate-400") { I18n.t("balances.monthly_analysis.#{key}") }
      p(class: "mt-2 text-sm font-semibold text-stone-900 dark:text-slate-100", data: { balances_monthly_analysis_target: target }) { "--" }
    end
  end

  def labels
    %i[
      error retry no_items income outcome net sent received failed contributed projected_contribution withdrawn projected_withdrawal
      recognized_profit_loss
    ].index_with { |key| I18n.t("balances.monthly_analysis.#{key}") }
  end
end
