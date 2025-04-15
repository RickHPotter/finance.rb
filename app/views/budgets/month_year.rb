# frozen_string_literal: true

class Views::Budgets::MonthYear < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :month_year, :month_year_str, :budgets

  def initialize(mobile:, month_year:, month_year_str:, budgets:)
    @month_year = month_year
    @mobile = mobile
    @month_year_str = month_year_str
    @budgets = budgets
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
      span(class: "py-3 col-start-7 text-end", id: :priceSum, data: { controller: "price-sum", price: budgets.sum(:remaining_value) })

      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 mb-4") do
        legend(class: "px-2 text-lg text-slate-800 text-start") { month_year_str }

        render Views::Budgets::Budgets.new(mobile:, budgets:)
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      span(class: "py-3 col-start-7 text-end", id: :priceSum, data: { controller: "price-sum", price: budgets.sum(:remaining_value) })

      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 mb-4") do
        legend(class: "px-2 text-lg text-slate-800 text-start") { month_year_str }

        div(class: "bg-white rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
          div(class: "grid grid-cols-8 px-2 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            div(class: "py-3")            { model_attribute(Budget, :date) }
            div(class: "py-3 col-span-3") { model_attribute(Budget, :description) }
            div(class: "py-3")            { model_attribute(Budget, :categories) }
            div(class: "py-3")            { model_attribute(Budget, :entities) }
            div(class: "py-3 text-end")   { model_attribute(Budget, :remaining_value) }
            div(class: "py-3 text-end")   { model_attribute(CashTransaction, :balance) }
          end

          if budgets.present?
            render Views::Budgets::Budgets.new(mobile:, budgets:)
          else
            div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
          end

          div(class: "grid grid-cols-8 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            span(class: "py-3 col-span-6 text-center") { "#{model_attribute(Budget, :total_amount)}:" }

            span(class: "py-3 col-start-7 text-end", id: :totalAmount, data: { controller: "price-sum", price: budgets.sum(:remaining_value) }) do
              from_cent_based_to_float(budgets.sum(:remaining_value), "R$")
            end
          end
        end
      end
    end
  end
end
