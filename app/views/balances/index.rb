# frozen_string_literal: true

class Views::Balances::Index < Views::Base
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect

  include CacheHelper
  include TranslateHelper

  def initialize(mobile:)
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "m-1 min-h-[calc(100svh-16rem)] rounded-lg bg-white shadow-md") do
        div(class: "flex items-start justify-between border-b border-stone-200 px-4 py-3") do
          div(class: "flex flex-col items-start") do
            h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700") { I18n.t("balances.title") }
            render_scenario_badge
          end
        end

        turbo_frame_tag :balance_chart do
          div(tabindex: "-1") do
            div(
              data: {
                controller: "monthly-balance",
                monthly_balance_url_value: cash_balance_json_balances_path(format: :json),
                monthly_balance_url_two_value: transaction_balance_json_balances_path(format: :json)
              }
            ) do
              div(class: "flex gap-2 items-center m-2") do
                select_tag(
                  nil,
                  class: "border rounded w-full py-1",
                  data: { action: "change->monthly-balance#rerender", monthly_balance_target: "chartType" }
                ) do
                  options_for_select([
                                       [ I18n.t("balances.types.default"), "default" ],
                                       [ I18n.t("balances.types.high_and_low"), "high_and_low" ],
                                       [ I18n.t("balances.types.month"), "month" ],
                                       [ I18n.t("balances.types.trimester"), "trimester" ],
                                       [ I18n.t("balances.types.semester"), "semester" ],
                                       [ I18n.t("balances.types.year"), "year" ]
                                     ], "default")
                end

                select_tag(
                  nil,
                  class: "border rounded w-full py-1",
                  data: { action: "change->monthly-balance#render", monthly_balance_target: "preset" }
                ) do
                  options_for_select([
                                       [ I18n.t("balances.all"), "all" ],
                                       [ I18n.t("balances.from_now"), "from_now" ],
                                       [ I18n.t("balances.until_now"), "until_now" ],
                                       [ I18n.t("balances.around_now"), "around_now" ]
                                     ], "from_now")
                end
              end

              div(class: "overflow-x-auto md:overflow-x-hidden") do
                div(class: "py-3", data: { monthly_balance_target: "pieRealm" }) do
                  span(class: "flex justify-center items-center gap-2 text-sm font-medium mx-auto rounded-sm py-3") do
                    button(
                      type: :button,
                      class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-500 px-2 py-1",
                      data: { action: "click->monthly-balance#prevMonth" }
                    ) do
                      "←"
                    end

                    div(class: "col-span-4 flex items-center") do
                      TextFieldTag \
                        form, :month_year,
                        type: :month,
                        class: "font-graduate",
                        value: Time.zone.today.strftime("%Y-%m"),
                        data: { monthly_balance_target: :monthInput }
                    end

                    button(
                      type: :button,
                      class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-500 px-2 py-1",
                      data: { action: "click->monthly-balance#nextMonth" }
                    ) do
                      "→"
                    end
                  end

                  div(class: "grid grid-cols-1 md:grid-cols-2") do
                    div(data: { monthly_balance_target: "negativePieChart", title: I18n.t("balances.types_titles.negative_amounts_pie") })
                    div(data: { monthly_balance_target: "positivePieChart", title: I18n.t("balances.types_titles.positive_amounts_pie") })

                    div(data: { monthly_balance_target: "negativeTransactionsPieChart", title: I18n.t("balances.types_titles.negative_transactions_pie") })
                    div(data: { monthly_balance_target: "positiveTransactionsPieChart", title: I18n.t("balances.types_titles.positive_transactions_pie") })
                  end

                  h1(class: "text-2xl font-bold text-gray-900 pt-3") do
                    I18n.t("balances.types_titles.period")
                  end
                end

                width = @mobile ? "390px" : "500px"
                div(class: "overflow-x-auto md:overflow-x-hidden", style: "min-width: #{width}") do
                  div(
                    style: "height: 600px",
                    data: {
                      monthly_balance_target: "chart",
                      default_title: I18n.t("balances.types_titles.default"),
                      high_title: I18n.t("balances.types_titles.high"),
                      low_title: I18n.t("balances.types_titles.low")
                    }
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
