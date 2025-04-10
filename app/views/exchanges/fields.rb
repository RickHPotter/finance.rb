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
          form.hidden_field :exchange_type, value: :monetary
          form.hidden_field :_destroy

          div(class: "grid grid-cols-1 my-1") do
            # select_tag :cash_transaction_id,
            #            options_from_collection_for_select([], :id, :description),
            #            class: "w-full border-1 border-gray-400 shadow-lg rounded-lg focus:ring-transparent focus:outline-none caret-transparent",
            #            data: { controller: "select", id: "cash-transaction-select" }
            #
            # turbo_frame_tag :cash_transactions do
            #   if exchange.cash_transaction
            #     turbo_frame_tag "cash_transaction_#{exchange.cash_transaction.id}", src: inspect_cash_transactions_path(id: exchange.cash_transaction.id)
            #   end
            # end

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
                                class: "price-input rounded-none rounded-e-lg bg-gray-50 border border-gray-300 text-gray-900 focus:ring-blue-500
                                       focus:border-blue-500 block flex-1 min-w-0 w-full text-sm p-2.5".squish,
                                data: { price_mask_target: :input, entity_transaction_target: :priceExchangeInput, action: "input->price-mask#applyMask" }
              end
            end
          end

          button(class: :hidden, data: { entity_transaction_target: "delExchange", action: "nested-form#remove" })
        end
      end
    end
  end
end
