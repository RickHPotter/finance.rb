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

              div(class: "bg-white shadow-lg rounded-lg p-4",
                  data: {
                    controller: "monthly-balance",
                    monthly_balance_url_value: json_balances_path(format: :json)
                  }) do
                div(class: "flex gap-2 items-center mb-4") do
                  select_tag(nil, class: "border rounded w-full py-1",
                                  data: { action: "change->monthly-balance#render", monthly_balance_target: "preset" }) do
                    options_for_select([
                                         [ I18n.t("balances.all"), "all" ],
                                         [ I18n.t("balances.from_now"), "from_now" ],
                                         [ I18n.t("balances.until_now"), "until_now" ],
                                         [ I18n.t("balances.around_now"), "around_now" ]
                                       ], "from_now")
                  end
                end

                div(class: "overflow-x-auto") do
                  div(style: "min-width: 500px") do
                    div(data: { monthly_balance_target: "chart", subtitle: I18n.t("balances.subtitle") }, style: "height: 400px")
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
