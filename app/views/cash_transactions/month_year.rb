# frozen_string_literal: true

class Views::CashTransactions::MonthYear < Views::Base
  include TranslateHelper

  attr_reader :mobile, :month_year, :month_year_date, :cash_installments, :budgets, :total_amount, :index_context

  def initialize(mobile:, month_year:, cash_installments:, budgets:, index_context: {})
    @mobile = mobile
    @month_year = month_year
    @month_year_date = Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01")
    @cash_installments = cash_installments
    @budgets = budgets
    @total_amount = cash_installments.sum(&:price) + budgets.sum(&:remaining_value)
    @index_context = index_context
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
    div(class: "mb-8", data: { datatable_target: :table, month_year_group: month_year }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg px-2 mb-4") do
        render Views::Shared::MonthYearHeader.new(month_year_str: I18n.l(month_year_date, format: "%b %Y"), total_amount:, mobile:)

        if cash_installments.present? || budgets.present?
          render Views::CashInstallments::Index.new(mobile:, cash_installments:, index_context:)
          render Views::Budgets::Budgets.new(mobile:, budgets:, show_rows_not_found: false)
        else
          div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
        end
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table, month_year_group: month_year }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4") do
        render Views::Shared::MonthYearHeader.new(month_year_str: I18n.l(month_year_date, format: "%B %Y"), total_amount:, mobile:)

        div(class: "bg-white rounded-lg border border-slate-300 shadow-sm overflow-hidden") do
          div(class: "rounded-t-lg border-b border-slate-400 bg-slate-200") do
            div(class: "grid grid-cols-12 gap-x-3 px-3 py-3 text-black font-graduate") do
              div(class: "col-span-5 col-start-1 gap-4 pb-2 pl-8") do
                render_header_label(model_attribute(CashTransaction, :description))
              end

              div(class: "col-span-3 flex justify-center pb-2") do
                render_header_label(model_attribute(CashTransaction, :categories))
              end

              div(class: "col-span-2 flex justify-center pb-2") do
                render_header_label(model_attribute(CashTransaction, :entities))
              end

              div(class: "flex items-end justify-end pb-2") do
                render_header_label(model_attribute(CashTransaction, :price), align: :right)
              end

              div(class: "flex items-end justify-end pb-2") do
                render_header_label(model_attribute(CashTransaction, :balance), align: :right)
              end
            end

            div(class: "flex flex-wrap items-center gap-2 border-t border-slate-300 bg-white/70 px-3 py-2 text-xs text-slate-600") do
              span(class: "uppercase tracking-[0.18em]") { I18n.t(:order) }
              span(class: "hidden text-gray-800 md:inline") { "->" }
              render_sort_button(label: I18n.t("balances.types.default"), field: "default", reset: true)
              span(class: "hidden text-gray-800 md:inline") { "|" }
              render_sort_button(label: model_attribute(CashTransaction, :cash_installment_date), field: "installment_date")
              span(class: "hidden text-zinc-400 md:inline") { "/" }
              render_sort_button(label: model_attribute(CashTransaction, :cash_transaction_date), field: "transaction_date")
              span(class: "hidden text-gray-800 md:inline") { "|" }
              render_sort_button(label: model_attribute(CashTransaction, :description), field: "description")
              span(class: "hidden text-gray-800 md:inline") { "|" }
              render_sort_button(label: model_attribute(CashTransaction, :price), field: "price")
            end
          end

          if cash_installments.present? || budgets.present?
            render Views::CashInstallments::Index.new(mobile:, cash_installments:, index_context:)
            render Views::Budgets::Budgets.new(mobile:, budgets:, show_rows_not_found: false)
          else
            div(class: "py-2 text-lg") { I18n.t(:rows_not_found) }
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

  private

  def render_header_label(label, align: :left)
    alignment = align == :right ? "text-right ml-auto" : ""

    span(class: "block text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-600 #{alignment}") { label }
  end

  def render_sort_button(label:, field:, reset: false)
    button(
      type: "button",
      class: sort_button_class(field),
      data: {
        action: "click->datatable#submitSort",
        sort_field: field,
        sort_default_direction: "asc",
        sort_reset: reset.to_s
      },
      aria: { pressed: active_sort?(field).to_s }
    ) do
      span(class: "text-xs md:text-sm") { label }
      span(class: sort_badge_class(field)) { sort_badge_label(field) }
    end
  end

  def sort_button_class(field)
    base = "inline-flex items-center gap-2 rounded-md ring transition-colors px-2 py-1 text-xs"
    state = active_sort?(field) ? "ring-blue-700 bg-blue-100 text-blue-900" : "ring-slate-400 bg-white text-slate-700 hover:ring-slate-600 hover:bg-slate-50"

    "#{base} #{state}"
  end

  def sort_badge_class(field)
    base = "rounded px-1.5 py-0.5 text-[10px] font-bold tracking-wide"
    state = active_sort?(field) ? "bg-blue-700 text-white" : "bg-slate-200 text-slate-700"

    "#{base} #{state}"
  end

  def sort_badge_label(field)
    return I18n.t("balances.mobile.current") if field == "default" && active_sort?(field)

    active_sort?(field) ? I18n.t("sorting.direction.#{current_direction}") : I18n.t("sorting.badge.idle")
  end

  def active_sort?(field)
    current_sort == field
  end

  def current_sort
    index_context[:sort]
  end

  def current_direction
    index_context[:direction]
  end
end
