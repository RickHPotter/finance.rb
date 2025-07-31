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
              div(class: "bg-white p-6 rounded-lg shadow-lg") do
                div(class: "bg-white shadow-lg rounded-lg p-4",
                    data: {
                      controller: "monthly-balance",
                      monthly_balance_url_value: json_balances_path(format: :json)
                    }) do
                  div(class: "flex gap-4 items-center mb-4") do
                    select_tag(nil, class: "border rounded w-full py-1",
                                    data: { action: "change->monthly-balance#updateFilter", monthly_balance_target: "preset" }) do
                      options_for_select([
                                           [ "All", "all" ],
                                           [ "From Now On", "from_now" ],
                                           [ "Until Now", "until_now" ],
                                           [ "Around Now", "around_now" ],
                                           [ "Custom", "custom" ]
                                         ])
                    end

                    input(type: "range", min: 0, max: 100, step: 1, value: 0,
                          data: { action: "input->monthly-balance#updateFilter", monthly_balance_target: "slider" },
                          class: "w-1/2")

                    span(data: { monthly_balance_target: "sliderLabel" }) { "0%" }
                  end

                  canvas(data: { monthly_balance_target: "canvas" }, height: @mobile ? "300" : "125")
                end
              end
            end
          end
        end
      end
    end
  end
end
