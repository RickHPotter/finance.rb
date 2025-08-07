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
          form.hidden_field :bound_type, class: :bound_type, value: exchange.new_record? ? :card_bound : exchange.bound_type
          form.hidden_field :exchange_type, value: :monetary
          form.hidden_field :month, class: :exchange_month
          form.hidden_field :year, class: :exchange_year
          form.hidden_field :_destroy, class: :exchange_destroy

          span(class: "flex justify-between items-center text-sm font-medium text-black mx-auto bg-gray-200 border border-gray-300 rounded-sm") do
            button(
              type: :button,
              class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-500 px-1
                     #{'opacity-0' if exchange.card_bound? || exchange.new_record?}",
              data: { action: "click->entity-transaction#prevMonth", entity_transaction_target: :button }
            ) do
              "←"
            end

            div(class: "col-span-4 flex items-center") do
              button(type: :button, class: "flex w-3 h-3 rounded-full me-2 flex-shrink-0 #{exchange.cash_transaction&.paid ? 'bg-green-400' : 'bg-orange-600'}")

              span(class: "exchange_month_year font-victor font-semibold text-orange-950", data: { entity_transaction_target: :monthYearExchange }) do
                exchange.month_year if exchange.month
              end
            end

            button(
              type: :button,
              class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-500 px-1
                     #{'opacity-0' if exchange.card_bound? || exchange.new_record?}",
              data: { action: "click->entity-transaction#nextMonth", entity_transaction_target: :button }
            ) do
              "→"
            end
          end

          div(class: "grid grid-cols-3 w-full") do
            div(class: "col-span-2") do
              div(class: "flex justify-center items-center text-sm text-gray-900 bg-gray-200 border border-gray-300 cursor-pointer rounded-none rounded-s-lg") do
                form.text_field \
                  :date,
                  id: :exchange_date,
                  type: "datetime-local",
                  value: (exchange.date || exchange.cash_transaction&.date)&.strftime("%Y-%m-%dT%H:%M"),
                  class: "exchange_date w-full outline-hidden appearance-none bg-transparent border-0 font-graduate text-[0.8rem]",
                  data: { entity_transaction_target: :dateInput }
              end
            end

            form.text_field \
              :price,
              inputmode: :numeric,
              class:
                "dynamic-price sign-based price-input rounded-none rounded-e-lg bg-gray-50 border border-gray-300 text-gray-900 focus:ring-blue-500
                focus:border-blue-500 block flex-1 min-w-0 w-full text-sm p-2.5",
              data: { price_mask_target: :input, entity_transaction_target: :priceExchangeInput, action: "input->price-mask#applyMask" }
          end

          button(type: :button, class: :hidden, tabindex: -1, data: { entity_transaction_target: "delExchange", action: "nested-form#remove" })
        end
      end
    end
  end
end
