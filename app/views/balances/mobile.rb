# frozen_string_literal: true

class Views::Balances::Mobile < Views::Base
  register_value_helper :current_context

  include Phlex::Rails::Helpers::LinkTo

  def view_template
    turbo_frame_tag :center_container do
      div(class: "m-1 min-h-[calc(100svh-16rem)] rounded-lg bg-white shadow-md shadow-red-50") do
        div(class: "flex items-start justify-between border-b border-stone-200 px-4 py-3") do
          div(class: "flex flex-col items-start") do
            h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700") { I18n.t("balances.title") }
            render_scenario_badge
          end

          link_to(
            legacy_balances_path,
            class: "inline-flex items-center rounded-full border border-stone-200 px-3 py-1 text-2xs " \
                   "font-semibold uppercase tracking-[0.16em] text-stone-600 transition hover:border-stone-400 hover:text-stone-900",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          ) { "Legacy" }
        end

        div(
          class: "space-y-5 pt-2",
          data: {
            controller: "balances-mobile",
            balances_mobile_summary_url_value: current_balance_json_balances_path(format: :json),
            balances_mobile_trend_url_value: cash_balance_json_balances_path(format: :json),
            balances_mobile_breakdown_url_value: transaction_balance_json_balances_path(format: :json)
          }
        ) do
          render_summary_cards
          render_trend_card
          render_breakdown_card
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
    div(class: "rounded-3xl border border-stone-200 bg-stone-50 px-3 py-1 shadow-sm") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500") { label }
      p(
        class: "mt-2 text-md font-semibold text-stone-900 transition-colors md:mt-1 md:text-base",
        data: { balances_mobile_target: target_name }
      ) { "--" }
    end
  end

  def render_trend_card
    div(class: "rounded-[28px] border border-stone-200 bg-gradient-to-br from-stone-50 via-white to-sky-50 p-4 shadow-sm") do
      div(class: "flex items-center justify-between gap-3") do
        div do
          p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500") { I18n.t("balances.mobile.trend") }
          p(class: "mt-1 text-sm font-medium text-stone-800") { I18n.t("balances.mobile.trend_subtitle") }
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

      div(class: "mt-4 rounded-3xl border border-stone-200 bg-white p-3") do
        div(class: "h-64") do
          canvas(data: { balances_mobile_target: "trendCanvas" })
        end
      end

      div(class: "mt-4 rounded-3xl border border-stone-200 bg-white p-3") do
        div do
          p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500") { I18n.t("balances.mobile.extremes") }
          p(class: "mt-1 text-sm font-medium text-stone-800") { I18n.t("balances.mobile.extremes_subtitle") }
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

  def render_breakdown_card
    div(class: "rounded-[28px] border border-stone-200 bg-gradient-to-br from-amber-50 via-white to-rose-50 p-4 shadow-sm") do
      div(class: "flex items-center justify-between gap-3") do
        div do
          p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500") { I18n.t("balances.mobile.breakdown") }
          p(class: "mt-1 text-sm font-medium text-stone-800") { I18n.t("balances.mobile.breakdown_subtitle") }
        end

        input(
          type: :month,
          value: Time.zone.today.strftime("%Y-%m"),
          class: "rounded-2xl border border-stone-200 bg-white px-3 py-2 text-sm text-stone-700",
          data: { balances_mobile_target: "monthInput", action: "change->balances-mobile#changeMonth" }
        )
      end

      div(class: "mt-4 rounded-3xl border border-stone-200 bg-white p-3") do
        div(class: "h-72") do
          canvas(data: { balances_mobile_target: "breakdownCanvas" })
        end
      end

      div(class: "mt-4 space-y-2", data: { balances_mobile_target: "legend" })
    end
  end

  def render_range_button(label, value, selected: false)
    button(
      type: :button,
      class: "inline-flex items-center rounded-full border px-3 py-1 text-2xs font-semibold uppercase tracking-[0.16em] transition " \
             "#{selected ? 'border-stone-900 bg-stone-900 text-white' : 'border-stone-200 bg-white text-stone-600'}",
      data: { balances_mobile_target: "rangeButton", range: value, action: "click->balances-mobile#changeRange" }
    ) { label }
  end

  def render_preset_button(label, value, selected: false)
    button(
      type: :button,
      class: "inline-flex items-center rounded-full border px-3 py-1 text-2xs font-semibold uppercase tracking-[0.16em] transition " \
             "#{selected ? 'border-sky-700 bg-sky-700 text-white' : 'border-stone-200 bg-white text-stone-600'}",
      data: { balances_mobile_target: "presetButton", preset: value, action: "click->balances-mobile#changePreset" }
    ) { label }
  end

  def render_scenario_badge
    div(class: "mt-2 inline-flex items-center border-l-4 border-red-700 bg-rose-400/30 px-3 py-1 text-2xs font-semibold uppercase") do
      plain(Context.model_name.human)
      plain(": ")
      plain(current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name)
    end
  end
end
