# frozen_string_literal: true

class Views::Budgets::MonthYear < Views::Base
  include TranslateHelper

  attr_reader :mobile, :month_year, :month_year_str, :budgets, :total_amount

  def initialize(mobile:, month_year:, month_year_str:, budgets:)
    @month_year = month_year
    @mobile = mobile
    @month_year_str = month_year_str
    @budgets = budgets
    @total_amount = budgets.sum(:remaining_value)
  end

  def view_template
    turbo_frame_tag "month_year_container_#{month_year}" do
      if mobile
        render_mobile_month_year
      else
        render_month_year
      end
    end
  end

  def render_mobile_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg px-2 mb-4 dark:border-slate-700") do
        render Views::Shared::MonthYearHeader.new(month_year_str:, total_amount:, mobile:)

        if budgets.present?
          render Views::Budgets::Budgets.new(mobile:, budgets:)
        else
          div(class: "border-b border-slate-200 py-2 my-2 text-lg dark:border-slate-700 dark:text-slate-100") { I18n.t(:rows_not_found) }
        end
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 dark:border-slate-700") do
        render Views::Shared::MonthYearHeader.new(month_year_str:, total_amount:, mobile:)

        div(class: "bg-white rounded-lg border border-slate-300 shadow-sm overflow-visible dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30") do
          render Views::Shared::TableHeader.new(
            grid_class: "grid grid-cols-12",
            rows: [
              [
                { class: "col-span-5 pl-8", label: model_attribute(Budget, :description) },
                { class: "col-span-3 flex justify-center", label: model_attribute(Budget, :categories), align: :center },
                { class: "col-span-2 flex justify-center", label: model_attribute(Budget, :entities), align: :center },
                { class: "flex items-end justify-end", label: model_attribute(Budget, :remaining), align: :right },
                { class: "flex items-end justify-end", label: model_attribute(CashTransaction, :balance), align: :right }
              ]
            ]
          )

          if budgets.present?
            render Views::Budgets::Budgets.new(mobile:, budgets:)
          else
            div(class: "py-2 text-lg dark:text-slate-100") { I18n.t(:rows_not_found) }
          end

          div(class: total_row_class) do
            span(class: "py-3 col-span-10 text-end") { "#{model_attribute(Budget, :total_amount)}:" }

            span(class: "py-3 col-span-2 text-center", id: :totalAmount, data: { price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end
        end
      end
    end
  end

  private

  def total_row_class
    "grid grid-cols-12 py-1 bg-slate-200 border-b border-slate-400 rounded-b-lg font-semibold text-black font-graduate " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
  end
end
