# frozen_string_literal: true

class Views::Investments::Edit < Views::Base
  def initialize(current_user:, investment:)
    @current_user = current_user
    @investment = investment
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        span(class: "rounded-sm border border-1 border-lime-400 bg-lime-200 px-3 shadow-md") { I18n.t("gerund.edit") }
        render Views::Investments::Form.new(current_user: @current_user, investment: @investment)
      end
    end
  end
end
