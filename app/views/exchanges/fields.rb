# frozen_string_literal: true

module Views
  module Exchanges
    class Fields < Views::Base
      attr_reader :form, :exchange

      def initialize(form:)
        @form = form
        @exchange = form.object
      end

      def view_template
        div(class: "nested-exchange-wrapper", data: { new_record: exchange.new_record?, entity_transaction_target: "exchangeWrapper" }) do
          form.hidden_field :id
          form.hidden_field :number, class: :exchange_number
          form.hidden_field :bound_type, class: :bound_type, value: exchange.bound_type || :card_bound
          form.hidden_field :exchange_type, value: :monetary
          form.hidden_field :_destroy, class: :exchange_destroy

          div(class: "grid grid-cols-1 my-1") do
            div(class: "flex w-full my-1") do
              div(class: "flex w-1/2") do
                span(class: "inline-flex items-center text-sm text-gray-900 bg-gray-200 border border-e-0 border-gray-300 rounded-s-md w-full") do
                  span(class: "flex items-center text-sm font-medium text-black ps-2") do
                    span(class: "flex w-3 h-3 bg-orange-500 rounded-full me-2 flex-shrink-0")
                    span(class: "exchange_month_year font-victor font-semibold text-orange-950", data: { entity_transaction_target: "monthYearExchange" }) do
                      exchange.cash_transaction&.month_year
                    end
                  end
                end
              end

              div(class: "flex w-1/2 font-graduate") do
                form.text_field :price,
                                class: "dynamic-price price-input rounded-none rounded-e-lg bg-gray-50 border border-gray-300 text-gray-900 focus:ring-blue-500
                                       focus:border-blue-500 block flex-1 min-w-0 w-full text-sm p-2.5".squish,
                                data: { price_mask_target: :input, entity_transaction_target: :priceExchangeInput, action: "input->price-mask#applyMask" }
              end
            end
          end

          button(type: :button, class: :hidden, tabindex: -1, data: { entity_transaction_target: "delExchange", action: "nested-form#remove" })
        end
      end
    end
  end
end
