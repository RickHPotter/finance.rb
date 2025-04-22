# frozen_string_literal: true

class Views::CardTransactions::MonthYear < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  include TranslateHelper

  attr_reader :mobile, :month_year, :month_year_str, :user_card_id, :card_installments, :card_installments_price

  def initialize(mobile:, month_year:, month_year_str:, user_card_id:, card_installments:)
    @month_year = month_year
    @mobile = mobile
    @month_year_str = month_year_str
    @user_card_id = user_card_id
    @card_installments = card_installments
    @card_installments_price = card_installments.sum(&:price)
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
      span(class: "py-3 col-start-7 text-end", id: :priceSum, data: { controller: "price-sum", price: card_installments_price })

      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 mb-4") do
        legend(class: "px-2 text-lg text-slate-800 text-start") { month_year_str }

        render Views::CardInstallments::Index.new(mobile:, card_installments:, user_card_id:)
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      span(class: "py-3 col-start-7 text-end", id: :priceSum, data: { controller: "price-sum", price: card_installments.sum(&:price) })

      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 mb-4") do
        legend(class: "px-2 text-lg text-slate-800 text-start") { month_year_str }

        div(class: "bg-white rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
          div(class: "grid grid-cols-8 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            div(class: "py-3")            { model_attribute(CardTransaction, :date) }
            div(class: "py-3 col-span-3") { model_attribute(CardTransaction, :description) }
            div(class: "py-3")            { model_attribute(CardTransaction, :categories) }
            div(class: "py-3")            { model_attribute(CardTransaction, :entities) }
            div(class: "py-3 text-end")   { model_attribute(CardTransaction, :price) }
            div(class: "py-3")            { I18n.t(:datatable_actions) }
          end

          if card_installments.present?
            render Views::CardInstallments::Index.new(mobile:, card_installments:, user_card_id:)
          else
            div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
          end

          div(class: "grid grid-cols-8 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            span(class: "py-3 col-span-6 text-center") { "#{model_attribute(CardTransaction, :total_amount)}:" }

            span(class: "py-3 col-start-7 text-end", id: :totalAmount, data: { controller: "price-sum", price: card_installments_price }) do
              from_cent_based_to_float(card_installments_price, "R$")
            end
          end
        end
      end
    end
  end
end
