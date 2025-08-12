# frozen_string_literal: true

class Views::CashTransactions::MonthYear < Views::Base
  include TranslateHelper

  attr_reader :mobile, :month_year, :month_year_str, :cash_installments, :budgets, :total_amount

  def initialize(mobile:, month_year:, month_year_str:, cash_installments:, budgets:)
    @month_year = month_year
    @mobile = mobile
    @month_year_str = month_year_str
    @cash_installments = cash_installments
    @budgets = budgets
    @total_amount = cash_installments.sum(&:price) + budgets.sum(&:remaining_value)
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
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg px-2 mb-4") do
        div(class: "pb-2 pt-6 text-slate-800 flex gap-2 relative") do
          div(class: "flex gap-2 absolute left-0 bottom-4") do
            span(class: "text-sm bg-blue-200 text-blue-900 border border-blue-600 py-1 px-2 rounded-lg") { month_year_str }

            span(class: "text-sm bg-red-200 text-red-900 border border-red-600 py-1 px-2 rounded-lg", id: :priceSum,
                 data: { price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end
        end

        render Views::CashInstallments::Index.new(mobile:, cash_installments:)
        render Views::Budgets::Budgets.new(mobile:, budgets:, show_rows_not_found: false)
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4") do
        div(class: "pb-2 pt-4 text-slate-800 flex gap-2 relative") do
          div(class: "flex gap-2 absolute left-0 bottom-4") do
            span(class: "text-sm bg-blue-200 text-blue-900 border border-blue-600 px-4 py-2 rounded-lg") { month_year_str }

            span(class: "text-sm bg-red-200 text-red-900 border border-red-600 px-4 py-2 rounded-lg", id: :priceSum,
                 data: { price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end

          if cash_installments.any? && cash_installments.none?(&:paid?)
            render Views::CashTransactions::PayMultipleModal.new(cash_installments:)

            Button(
              class: "absolute right-0 bottom-4",
              title: model_attribute(CashInstallment, :pay),
              data: { modal_target: "cashInstallmentsModal", modal_toggle: "cashInstallmentsModal" }
            ) do
              model_attribute(CashInstallment, :pay)
            end
          end
        end

        div(class: "bg-white rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
          div(class: "grid grid-cols-12 px-2 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            div(class: "py-3 col-span-5") { model_attribute(CashTransaction, :description) }
            div(class: "py-3 col-span-3") { model_attribute(CashTransaction, :categories) }
            div(class: "py-3 col-span-2") { model_attribute(CashTransaction, :entities) }
            div(class: "py-3 text-end")   { model_attribute(CashTransaction, :price) }
            div(class: "py-3 text-end")   { model_attribute(CashTransaction, :balance) }
          end

          if cash_installments.present? || budgets.present?
            render Views::CashInstallments::Index.new(mobile:, cash_installments:)
            render Views::Budgets::Budgets.new(mobile:, budgets:, show_rows_not_found: false)
          else
            div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
          end

          div(class: "grid grid-cols-12 py-1 bg-slate-200 border-b border-slate-400 rounded-b-lg font-semibold text-black font-graduate") do
            span(class: "py-3 col-span-10 text-end") { "#{model_attribute(CashTransaction, :total_amount)}:" }

            span(class: "py-3 col-start-11 text-end", id: :totalAmount, data: { price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end
        end
      end
    end
  end
end
