# frozen_string_literal: true

module Views
  module Exchanges
    class Fields < Components::Base
      include Phlex::Rails::Helpers::SelectTag
      include Phlex::Rails::Helpers::OptionsFromCollectionForSelect
      include Phlex::Rails::Helpers::TurboFrameTag

      attr_reader :form, :exchange

      def initialize(form:)
        @form = form
        @exchange = form.object
      end

      def view_template
        div(class: "nested-exchange-wrapper", data: { new_record: exchange.new_record?, reactive_form_target: "exchangeWrapper" }) do
          div(class: "flex my-1") do
            select_tag :cash_transaction_id,
                       options_from_collection_for_select([], :id, :description),
                       class: "w-full border-1 border-gray-400 shadow-lg rounded-lg focus:ring-transparent focus:outline-none caret-transparent",
                       data: { controller: "select", id: "cash-transaction-select" }

            turbo_frame_tag :cash_transactions do
              if exchange.cash_transaction
                turbo_frame_tag "cash_transaction_#{exchange.cash_transaction.id}", src: inspect_cash_transactions_path(id: exchange.cash_transaction.id)
              end
            end

            div(class: "flex w-full my-1") do
              div(class: "flex w-2/5") do
                span(class: "inline-flex items-center text-sm text-gray-900 bg-gray-200 border border-e-0 border-gray-300 rounded-s-md w-full") do
                  span(class: "flex items-center text-sm font-medium text-black ps-2") do
                    span(class: "flex w-3 h-3 bg-orange-500 rounded-full me-2 flex-shrink-0")
                    span(class: "exchange_month_year font-victor font-semibold text-orange-950", data: { entity_transaction_target: "monthYearExchange" }) do
                      exchange.cash_transaction&.month_year
                    end
                  end
                end
              end

              div(class: "flex w-2/5 font-graduate") do
                form.text_field :price,
                                class: "price-input rounded-none rounded-e-lg bg-gray-50 border border-gray-300 text-gray-900 focus:ring-blue-500
                                       focus:border-blue-500 block flex-1 min-w-0 w-full text-sm p-2.5".squish,
                                data: { price_mask_target: :input, entity_transaction_target: :priceExchangeInput, action: "input->price-mask#applyMask" }
              end
            end
          end

          form.hidden_field :id
          form.hidden_field :number, class: :exchange_number
          form.hidden_field :exchange_type, value: :monetary
          form.hidden_field :_destroy

          button(class: :hidden, data: { entity_transaction_target: "delExchange", action: "nested-form#remove" })
        end
      end
    end
  end
end
