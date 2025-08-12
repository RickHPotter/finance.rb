# frozen_string_literal: true

class Views::Lalas::CardTransactions::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term,
              :category_id, :entity_id,
              :user_card

  def initialize(index_context: {})
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @user_card = index_context[:user_card]
  end

  def view_template
    form_with url: card_transactions_lalas_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |_form|
      div class: "mb-6 flex gap-4 flex-wrap" do
        month_year_selector(default_year:, years:, active_month_years:)
      end

      TextFieldTag :user_card_id, class: :hidden, value: params[:user_card_id] || params.dig(:card_transaction, :user_card_id) || user_card&.id

      div(class: "flex justify-between items-center gap-2") do
        div(class: "flex-1") do
          TextFieldTag \
            :search_term,
            svg: :magnifying_glass,
            clearable: true,
            placeholder: "#{action_message(:search)}...",
            value: search_term,
            data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }
        end
      end
    end
  end

  def month_year_selector(default_year:, years:, active_month_years:)
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
