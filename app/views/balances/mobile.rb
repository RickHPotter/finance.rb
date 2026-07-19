# frozen_string_literal: true

class Views::Balances::Mobile < Views::Base
  register_value_helper :current_context

  include Phlex::Rails::Helpers::LinkTo
  include Views::Balances::AnalysisTabs

  def view_template
    turbo_frame_tag :center_container do
      div(class: mobile_shell_class) do
        div(class: mobile_header_class) do
          div(class: "flex flex-col items-start") do
            h1(class: mobile_title_class) { I18n.t("balances.title") }
            render_scenario_badge
          end

          link_to(
            legacy_balances_path,
            class: legacy_button_class,
            data: { turbo_frame: "_top", turbo_prefetch: false }
          ) { "Legacy" }
        end

        div(class: "pt-2", data: { controller: "naming-tabs", naming_tabs_current_value: "overview" }) do
          render_analysis_tabs

          div(id: "balances_overview_panel", role: :tabpanel, data: { naming_tabs_target: "panel", naming_tabs_name: "overview" }) do
            div(
              class: "space-y-5",
              data: {
                controller: "balances-mobile",
                balances_mobile_summary_url_value: current_balance_json_balances_path(format: :json),
                balances_mobile_trend_url_value: cash_balance_json_balances_path(format: :json)
              }
            ) do
              render_summary_cards
              render_trend_card
            end
          end

          div(id: "balances_monthly_analysis_panel", role: :tabpanel, class: "hidden px-4 pb-4",
              data: { naming_tabs_target: "panel", naming_tabs_name: "monthly_analysis" }) do
            turbo_frame_tag :balances_monthly_analysis_content, data: { naming_tabs_lazy_src: monthly_analysis_balances_path } do
              analysis_loading_state
            end
          end
        end
      end
    end
  end

  private

  def render_summary_cards
    div(class: "grid grid-cols-1 gap-2 md:grid-cols-3") do
      render_metric_card(I18n.t("balances.mobile.low"), "lowValue")
      render_metric_card(I18n.t("balances.mobile.current"), "currentValue")
      render_metric_card(I18n.t("balances.mobile.high"), "highValue")
    end
  end

  def render_metric_card(label, target_name)
    div(class: "rounded-3xl border border-stone-200 bg-stone-50 px-3 py-1 shadow-sm dark:border-slate-700 dark:bg-slate-800 dark:shadow-none") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500 dark:text-slate-400") { label }
      p(
        class: "mt-2 text-md font-semibold text-stone-900 transition-colors md:mt-1 md:text-base dark:text-slate-100",
        data: { balances_mobile_target: target_name }
      ) { "--" }
    end
  end

  def render_trend_card
    div(class: trend_card_class) do
      div(class: "flex items-center justify-between gap-3") do
        div do
          p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500 dark:text-slate-400") { I18n.t("balances.mobile.trend") }
          p(class: "mt-1 text-sm font-medium text-stone-800 dark:text-slate-200") { I18n.t("balances.mobile.trend_subtitle") }
        end
      end

      div(class: "mt-4 flex flex-wrap items-center gap-2") do
        render_preset_button(I18n.t("balances.from_now"), "from_now", selected: true)
        render_preset_button(I18n.t("balances.around_now"), "around_now")
        render_preset_button(I18n.t("balances.until_now"), "until_now")
      end

      div(class: "mt-2 flex flex-wrap items-center gap-2") do
        render_range_button(I18n.t("balances.mobile.three_months"), "3m")
        render_range_button(I18n.t("balances.mobile.six_months"), "6m")
        render_range_button(I18n.t("balances.mobile.one_year"), "1y", selected: true)
        render_range_button(I18n.t("balances.all"), "all")
      end

      div(class: chart_panel_class) do
        div(class: "h-64") do
          canvas(data: { balances_mobile_target: "trendCanvas" })
        end
      end

      div(class: chart_panel_class) do
        div do
          p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500 dark:text-slate-400") { I18n.t("balances.mobile.extremes") }
          p(class: "mt-1 text-sm font-medium text-stone-800 dark:text-slate-200") { I18n.t("balances.mobile.extremes_subtitle") }
        end

        div(class: "mt-4") do
          div(class: "h-40") do
            canvas(
              data: {
                balances_mobile_target: "extremesCanvas",
                high_label: I18n.t("balances.mobile.high"),
                low_label: I18n.t("balances.mobile.low")
              }
            )
          end
        end
      end
    end
  end

  def render_range_button(label, value, selected: false)
    button(
      type: :button,
      class: pill_button_class(selected:, active_class: "border-stone-900 bg-stone-900 text-white dark:border-slate-100 dark:bg-slate-100 dark:text-slate-950"),
      data: { balances_mobile_target: "rangeButton", range: value, action: "click->balances-mobile#changeRange" }
    ) { label }
  end

  def render_preset_button(label, value, selected: false)
    button(
      type: :button,
      class: pill_button_class(selected:, active_class: "border-sky-700 bg-sky-700 text-white dark:border-sky-500 dark:bg-sky-700 dark:text-white"),
      data: { balances_mobile_target: "presetButton", preset: value, action: "click->balances-mobile#changePreset" }
    ) { label }
  end

  def mobile_shell_class
    "m-1 min-h-[calc(100svh-16rem)] rounded-lg bg-white shadow-md shadow-red-50 dark:border dark:border-slate-800 dark:bg-slate-900 " \
      "dark:text-slate-100 dark:shadow-none"
  end

  def mobile_header_class
    "flex items-start justify-between border-b border-stone-200 px-4 py-3 dark:border-slate-700"
  end

  def mobile_title_class
    "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700 dark:text-slate-300"
  end

  def legacy_button_class
    "inline-flex items-center rounded-full border border-stone-200 px-3 py-1 text-2xs font-semibold uppercase tracking-[0.16em] " \
      "text-stone-600 transition hover:border-stone-400 hover:text-stone-900 dark:border-slate-700 dark:text-slate-300 " \
      "dark:hover:border-slate-500 dark:hover:text-slate-100"
  end

  def chart_panel_class
    "mt-4 rounded-3xl border border-stone-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950"
  end

  def trend_card_class
    "rounded-[28px] border border-stone-200 bg-linear-to-br from-stone-50 via-white to-sky-50 p-4 shadow-sm " \
      "dark:border-slate-700 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800 dark:shadow-none"
  end

  def pill_button_class(selected:, active_class:)
    base = "inline-flex items-center rounded-full border px-3 py-1 text-2xs font-semibold uppercase tracking-[0.16em] transition"
    inactive = "border-stone-200 bg-white text-stone-600 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300"

    "#{base} #{selected ? active_class : inactive}"
  end

  def render_scenario_badge
    return if current_context.main?

    div(class: "mt-2 inline-flex items-center border-l-4 border-red-700 bg-rose-400/30 px-3 py-1 text-2xs font-semibold uppercase") do
      plain(Context.model_name.human)
      plain(": ")
      plain(current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name)
    end
  end
end
