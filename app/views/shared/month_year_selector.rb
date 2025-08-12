# frozen_string_literal: true

class Views::Shared::MonthYearSelector < Views::Base
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::LinkTo

  include ContextHelper

  attr_reader :current_user, :form_id, :default_year, :years, :active_month_years

  def initialize(current_user:, form_id:, default_year:, years:, active_month_years:)
    @current_user = current_user
    @form_id = form_id
    @default_year = default_year
    @years = years
    @active_month_years = active_month_years
  end

  def view_template(&)
    div(class: "w-full", data: { controller: "month-year-selector", form_id: "search_form" }) do
      text_field_tag :default_year, default_year, class: "hidden", data: { month_year_selector_target: "defaultYear" }
      text_field_tag :active_month_years, active_month_years.to_json, class: "hidden", data: { month_year_selector_target: "monthYears" }

      years.each do |year|
        div(class: ("active" if year == default_year), data: { month_year_selector_target: "monthYearContainer", year: }) do
          div(class: "flex justify-between") do
            div(class: "flex items-center gap-4") do
              button(
                type: :button,
                class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-600 p-1
                             #{'opacity-10 pointer-events-none' if year == years.first}",
                data: { action: "click->month-year-selector#prevYear", year: }
              ) do
                "←"
              end

              span(class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-600 p-1") { year }

              button(
                type: :button,
                class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-600 p-1
                             #{'opacity-10 pointer-events-none' if year == years.last}",
                data: { action: "click->month-year-selector#nextYear", year: }
              ) do
                "→"
              end
            end

            div(class: "flex items-center gap-4", &)
          end

          div(class: "grid 2xl:grid-cols-12 xl:grid-cols-6 lg:grid-cols-4 grid-cols-3 pt-3 gap-2") do
            (1..12).each do |month|
              month_year = Date.new(year, month, 1).strftime("%Y%m").to_i

              button(
                type: :button,
                class: "p-1 rounded-lg bg-background shadow-sm hover:bg-blue-100 transition-colors",
                data: {
                  month_year_selector_target: "monthYear",
                  action: "mousedown->month-year-selector#activate mouseup->month-year-selector#stop",
                  month_year:,
                  active: active_month_years.include?(month_year)
                }
              ) do
                span(class: "block sm:hidden pointer-events-none no-selection") { I18n.t("date.abbr_month_names")[month] }
                span(class: "hidden sm:block pointer-events-none no-selection") { I18n.t("date.month_names")[month] }
              end
            end
          end
        end
      end
    end
  end
end
