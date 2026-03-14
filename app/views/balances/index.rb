# frozen_string_literal: true

class Views::Balances::Index < Views::Base
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect

  include CacheHelper

  def initialize(mobile:)
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :balance_chart do
            div(
              class: "min-h-screen",
              tabindex: "-1"
            ) do
              div(class: "text-center") do
                div(class: "inline-flex items-center justify-center w-16 h-16 rounded-full bg-blue-100 text-blue-600 mb-4") do
                  h1(class: "text-3xl font-bold text-gray-900 mb-3") do
                    I18n.t("balances.title")
                  end
                end
              end

              div(class: "bg-white shadow-lg rounded-lg p-2",
                  data: {
                    controller: "monthly-balance",
                    monthly_balance_url_value: cash_balance_json_balances_path(format: :json),
                    monthly_balance_url_two_value: transaction_balance_json_balances_path(format: :json)
                  }) do
                div(class: "flex gap-2 items-center mb-4") do
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
end
