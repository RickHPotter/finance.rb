# frozen_string_literal: true

class Views::CardTransactions::MonthYear < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  include TranslateHelper

  attr_reader :mobile, :month_year, :month_year_date, :month, :year, :month_year_str, :user_card_id,
              :card_installments, :total_amount, :modal_id,
              :min_date, :max_date

  def initialize(mobile:, month_year:, user_card_id:, card_installments:)
    @mobile = mobile
    @month_year = month_year
    @month_year_date = Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01")
    @month = month_year_date.month
    @year = month_year_date.year
    @month_year_str = I18n.l(month_year_date, format: "%B %Y")
    @user_card_id = user_card_id
    @card_installments = card_installments
    @total_amount = card_installments.sum(&:price)
    @modal_id = "cardTransactionModal_#{user_card_id}_#{month}_#{year}"

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
        div(class: "pb-2 pt-6 text-slate-800 flex gap-2 relative") do
          div(class: "flex gap-2 absolute left-0 bottom-4") do
            span(class: "text-sm bg-blue-200 text-blue-900 border border-blue-600 py-1 px-2 rounded-lg") { month_year_str }

            span(class: "text-sm bg-red-200 text-red-900 border border-red-600 py-1 px-2 rounded-lg", id: :priceSum,
                 data: {  price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end

          if user_card_id && card_installments.any?
            render Views::CardTransactions::PayInAdvanceModal.new(month:, year:, user_card_id:, min_date:, max_date:)

            Button(size: :sm, class: "absolute right-0 bottom-4", data: { modal_target: modal_id, modal_toggle: modal_id }) do
              model_attribute(CardTransaction, :pay_in_advance)
            end
          end
        end

        render Views::CardInstallments::Index.new(mobile:, card_installments:, user_card_id:)
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
                 data: {  price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end

          if user_card_id && card_installments.any?
            render Views::CardTransactions::PayInAdvanceModal.new(month:, year:, user_card_id:, min_date:, max_date:)

            Button(class: "absolute right-0 bottom-4", data: { modal_target: modal_id, modal_toggle: modal_id }) do
              model_attribute(CardTransaction, :pay_in_advance)
            end
          end
        end

        div(class: "bg-white rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
          div(class: "grid grid-cols-12 px-2 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            div(class: "py-3 col-span-5") { model_attribute(CardTransaction, :description) }
            div(class: "py-3 col-span-3") { model_attribute(CardTransaction, :categories) }
            div(class: "py-3 col-span-2") { model_attribute(CardTransaction, :entities) }
            div(class: "py-3 text-end")   { model_attribute(CardTransaction, :price) }
            div(class: "py-3 text-end")   { I18n.t(:datatable_actions) }
          end

          if card_installments.present?
            render Views::CardInstallments::Index.new(mobile:, card_installments:, user_card_id:)
          else
            div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
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
end
