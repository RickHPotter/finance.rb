# frozen_string_literal: true

class Views::CardTransactions::MonthYear < Views::Base
  include Phlex::Rails::Helpers::ButtonTag

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :month_year, :month_year_date, :month, :year, :user_card_id,
              :card_installments, :total_amount, :modal_id,
              :min_date, :max_date, :sort, :direction

  def initialize(mobile:, month_year:, user_card_id:, card_installments:, sort_state: {})
    @mobile = mobile
    @month_year = month_year
    @month_year_date = Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01")
    @month = month_year_date.month
    @year = month_year_date.year
    @user_card_id = user_card_id
    @card_installments = card_installments
    @total_amount = card_installments.sum(&:price)
    @modal_id = "cardTransactionModal_#{user_card_id}_#{month}_#{year}"
    @sort = sort_state[:sort]
    @direction = sort_state[:direction]

    return unless user_card_id

    user_card = UserCard.find(user_card_id)
    references = user_card.references
    past_month_reference = references.find_by_month_year(month_year_date - 1.month)&.reference_closing_date
    curr_month_reference = references.find_by_month_year(month_year_date)&.reference_date

    return if past_month_reference.nil? && curr_month_reference.nil?

    @min_date = past_month_reference&.to_datetime&.strftime("%Y-%m-%dT%H:%M")
    @max_date = curr_month_reference&.to_datetime&.strftime("%Y-%m-%dT%H:%M")
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
        render Views::Shared::MonthYearHeader.new(month_year_str: I18n.l(month_year_date, format: "%b %Y"), total_amount:, mobile:) do
          if user_card_id && card_installments.any? && !card_installments.first.cash_transaction.paid?
            render Views::CardTransactions::PayInAdvanceModal.new(month:, year:, user_card_id:, min_date:, max_date:)

            Button(size: :sm, class: "absolute right-0 bottom-4", data: { modal_target: modal_id, modal_toggle: modal_id }) do
              model_attribute(CardTransaction, :pay_in_advance)
            end
          end
        end

        if card_installments.present?
          render Views::CardInstallments::Index.new(mobile:, card_installments:, user_card_id:)
        else
          div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
        end
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4") do
        render Views::Shared::MonthYearHeader.new(month_year_str: I18n.l(month_year_date, format: "%B %Y"), total_amount:, mobile:) do
          if user_card_id && card_installments.any? && !card_installments.first.cash_transaction.paid?
            render Views::CardTransactions::PayInAdvanceModal.new(month:, year:, user_card_id:, min_date:, max_date:)

            Button(class: "absolute right-0 bottom-4", data: { modal_target: modal_id, modal_toggle: modal_id }) do
              model_attribute(CardTransaction, :pay_in_advance)
            end
          end
        end

        div(class: "bg-white rounded-lg border border-slate-300 shadow-sm overflow-hidden") do
          div(class: "rounded-t-lg border-b border-slate-400 bg-slate-200") do
            div(class: "grid grid-cols-12 gap-x-3 px-3 py-3 text-black font-graduate") do
              div(class: "col-span-5 col-start-1 gap-4 pb-2 pl-8") do
                render_header_label(model_attribute(CardTransaction, :description))
              end

              div(class: "col-span-3 flex justify-center pb-2") do
                render_header_label(model_attribute(CardTransaction, :categories))
              end

              div(class: "col-span-2 flex justify-center pb-2") do
                render_header_label(model_attribute(CardTransaction, :entities))
              end

              div(class: "flex items-end justify-end pb-2") do
                render_header_label(model_attribute(CardTransaction, :price), align: :right)
              end

              div(class: "flex items-end justify-end pb-2") do
                render_header_label(I18n.t(:datatable_actions), align: :right)
              end
            end

            div(class: "flex flex-wrap items-center gap-2 border-t border-slate-300 bg-white/70 px-3 py-2 text-xs text-slate-600") do
              span(class: "uppercase tracking-[0.18em]") { I18n.t(:order) }
              span(class: "hidden text-gray-800 md:inline") { "->" }
              render_sort_button(label: model_attribute(CardTransaction, :card_installment_date), field: "installment_date")
              span(class: "hidden text-zinc-400 md:inline") { "/" }
              render_sort_button(label: model_attribute(CardTransaction, :card_transaction_date), field: "transaction_date")
              span(class: "hidden text-gray-800 md:inline") { "|" }
              render_sort_button(label: model_attribute(CardTransaction, :description), field: "description")
              span(class: "hidden text-gray-800 md:inline") { "|" }
              render_sort_button(label: model_attribute(CardTransaction, :price), field: "price")
            end
          end

          if card_installments.present?
            render Views::CardInstallments::Index.new(mobile:, card_installments:, user_card_id:)
          else
            div(class: "py-2 text-lg") { I18n.t(:rows_not_found) }
          end

          div(class: "grid grid-cols-12 py-1 bg-slate-200 border-b border-slate-400 rounded-b-lg font-semibold text-black font-graduate") do
            span(class: "py-3 col-span-10 text-end") { "#{model_attribute(CardTransaction, :total_amount)}:" }

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
    span(class: header_label_class(align)) { label }
  end

  def render_sort_button(label:, field:)
    button(
      type: "button",
      class: sort_button_class(field),
      data: {
        action: "click->datatable#submitSort",
        sort_field: field,
        sort_default_direction: "asc"
      },
      aria: { pressed: active_sort?(field).to_s }
    ) do
      span(class: sort_button_label_class) { label }
      span(class: sort_badge_class(field)) { sort_badge_label(field) }
    end
  end

  def header_label_class(align)
    alignment = align == :right ? "text-right ml-auto" : ""

    "block text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-600 #{alignment}"
  end

  def sort_button_class(field)
    base = "inline-flex items-center gap-2 rounded-md ring transition-colors"
    spacing = "px-2 py-1"
    size = "text-xs"
    state =
      if active_sort?(field)
        "ring-blue-700 bg-blue-100 text-blue-900"
      else
        "ring-slate-400 bg-white text-slate-700 hover:ring-slate-600 hover:bg-slate-50"
      end

    "#{base} #{spacing} #{size} #{state}"
  end

  def sort_button_label_class
    "text-xs md:text-sm"
  end

  def sort_badge_class(field)
    base = "rounded px-1.5 py-0.5 text-[10px] font-bold tracking-wide"
    state = active_sort?(field) ? "bg-blue-700 text-white" : "bg-slate-200 text-slate-700"

    "#{base} #{state}"
  end

  def sort_badge_label(field)
    active_sort?(field) ? I18n.t("sorting.direction.#{direction}") : I18n.t("sorting.badge.idle")
  end

  def active_sort?(field)
    sort == field
  end
end
