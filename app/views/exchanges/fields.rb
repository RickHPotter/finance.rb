# frozen_string_literal: true

module Views
  module Exchanges
    class Fields < Views::Base
      attr_reader :form, :exchange

      include CacheHelper

      def initialize(form:)
        @form = form
        @exchange = form.object
      end

      def view_template
        transactable = form.options[:parent_builder].options[:parent_builder].object
        if transactable.is_a?(CashTransaction)
          :standalone
        elsif exchange.new_record? && !transactable.duplicate
          :card_bound
        else
          exchange.bound_type.to_sym
        end => bound_type

        div(
          class: "nested-exchange-wrapper bg-white border rounded-xl p-3 shadow-sm space-y-1 transition hover:shadow-md
                  #{locked? ? 'border-red-300' : 'border-green-300'}",
          data: {
            new_record: exchange.new_record?,
            entity_transaction_target: "exchangeWrapper",
            exchange_lock_target: "exchange",
            locked: locked?.to_s
          }
        ) do
          form.hidden_field :id
          form.hidden_field :number, class: :exchange_number
          form.hidden_field :bound_type, class: :bound_type, value: bound_type
          form.hidden_field :exchange_type, value: :monetary
          form.hidden_field :month, class: :exchange_month
          form.hidden_field :year, class: :exchange_year
          form.hidden_field :_destroy, class: :exchange_destroy

          div(class: "flex justify-between items-center text-md font-medium bg-gray-100 border border-gray-200 rounded-lg px-2 py-1") do
            button(
              type: :button,
              class: "text-base font-bold rounded-md px-1 text-gray-700 hover:text-gray-900 transition",
              data: { action: "click->entity-transaction#prevMonth", entity_transaction_target: :button }
            ) { "←" }

            div(class: "flex items-center gap-2") do
              div(class: "w-3 h-3 rounded-full #{exchange.cash_transaction&.paid ? 'bg-green-400' : 'bg-orange-500'} border border-white shadow-sm")
              span(
                class: "exchange_month_year font-victor font-semibold text-gray-900 tracking-wide",
                data: { entity_transaction_target: :monthYearExchange }
              ) { exchange.month_year if exchange.month }
            end

            button(
              type: :button,
              class: "text-base font-bold rounded-md px-1 text-gray-700 hover:text-gray-900 transition",
              data: { action: "click->entity-transaction#nextMonth", entity_transaction_target: :button }
            ) { "→" }
          end

          div(class: "flex-1 grid gap-1") do
            form.text_field \
              :date,
              id: :exchange_date,
              type: "datetime-local",
              value: (exchange.date || exchange.cash_transaction&.date)&.strftime("%Y-%m-%dT%H:%M"),
              class: "exchange_date
                      w-full border border-gray-300 bg-gray-50 text-gray-900 text-sm rounded-lg p-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
              readonly: bound_type == :card_bound,
              data: { entity_transaction_target: :dateInput, action: "change->entity-transaction#updateReferenceMonthYear" }

            div(class: "flex gap-1") do
              form.text_field \
                :price,
                inputmode: :numeric,
                class: "dynamic-price sign-based price-input
                        w-full border border-gray-300 bg-gray-50 text-gray-900 text-sm rounded-lg p-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
                onclick: "this.select();",
                data: {
                  price_mask_target: :input,
                  entity_transaction_target: :priceExchangeInput,
                  exchange_lock_target: :price,
                  action: "input->price-mask#applyMask"
                }

              div do
                button(
                  type: "button",
                  class: "p-1.5 rounded-md bg-green-200 hover:bg-gray-100 border border-gray-300 #{'hidden' if locked?}",
                  data: { exchange_lock_target: :lockBtn, action: "click->exchange-lock#lock" }
                ) { cached_icon :unlocked_padlock }

                button(
                  type: "button",
                  class: "p-1.5 rounded-md bg-red-200 hover:bg-gray-100 border border-gray-300 #{'hidden' unless locked?}",
                  data: { exchange_lock_target: :unlockBtn, action: "click->exchange-lock#unlock" }
                ) { cached_icon :locked_padlock }
              end
            end
          end

          button(type: :button, class: :hidden, tabindex: -1, data: { entity_transaction_target: "delExchange", action: "nested-form#remove" })
        end
      end

      def locked?
        exchange.cash_transaction&.paid? || false
      end
    end
  end
end
