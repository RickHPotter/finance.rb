# frozen_string_literal: true

module Views
  module Exchanges
    class Fields < Views::Base
      include Phlex::Rails::Helpers::HiddenFieldTag

      attr_reader :form, :exchange, :bound_type

      include CacheHelper

      def initialize(form:, bound_type:)
        @form = form
        @exchange = form.object
        @bound_type = bound_type
      end

      def view_template
        div(
          class: "nested-exchange-wrapper rounded-xl border bg-white p-3 shadow-sm space-y-1 transition hover:shadow-md dark:bg-slate-900/70 " \
                 "dark:shadow-none #{exchange_border_class}",
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
          hidden_field_tag "#{form.object_name}[paid]", exchange.effective_paid_state
          form.hidden_field :_destroy, class: :exchange_destroy

          div(
            class: "flex justify-between items-center text-md font-medium bg-gray-100 border border-gray-200 rounded-lg px-2 py-1 " \
                   "dark:border-slate-700 dark:bg-slate-800"
          ) do
            button(
              type: :button,
              class: "text-base font-bold rounded-md px-1 text-gray-700 hover:text-gray-900 transition dark:text-slate-400 dark:hover:text-slate-100",
              data: { action: "click->entity-transaction#prevMonth", entity_transaction_target: :button }
            ) { "←" }

            div(class: "flex items-center gap-2") do
              span(class: "exchange_number_display text-gray-300 dark:font-mono dark:text-slate-600") do
                exchange.number
              end

              paid = exchange.effective_paid_state
              div(class: "w-3 h-3 rounded-full #{paid ? 'bg-green-400' : 'bg-orange-500'} border border-white shadow-sm")

              span(
                class: "exchange_month_year text-gray-900 dark:font-mono dark:text-xs dark:uppercase dark:tracking-wide dark:text-slate-300",
                data: { entity_transaction_target: :monthYearExchange }
              ) { exchange.month_year if exchange.month }
            end

            button(
              type: :button,
              class: "text-base font-bold rounded-md px-1 text-gray-700 hover:text-gray-900 transition dark:text-slate-400 dark:hover:text-slate-100",
              data: { action: "click->entity-transaction#nextMonth", entity_transaction_target: :button }
            ) { "→" }
          end

          div(class: "flex-1 grid gap-1") do
            render Views::Shared::DatetimeInput.new(
              form:,
              field: :date,
              value: exchange.date || exchange.cash_transaction&.date,
              id: exchange_date_id,
              hidden_class: "exchange_date",
              hidden_data: {
                entity_transaction_target: :dateInput,
                action: "change->entity-transaction#updateReferenceMonthYear"
              },
              compact: true,
              readonly: bound_type == :card_bound
            )

            div(class: "flex gap-1") do
              form.text_field \
                :price,
                inputmode: :numeric,
                class: exchange_input_class("dynamic-price sign-based price-input"),
                readonly: locked?,
                aria: { readonly: locked? },
                data: {
                  controller: "input-select",
                  price_mask_target: :input,
                  entity_transaction_target: :priceExchangeInput,
                  exchange_lock_target: :price,
                  action: "click->input-select#select input->price-mask#applyMask"
                }

              div do
                button(
                  type: "button",
                  class: "p-1.5 rounded-md bg-red-300 text-black hover:bg-gray-100 border border-gray-300 " \
                         "dark:border-red-500/50 dark:bg-red-500/20 dark:text-red-200 dark:hover:bg-red-500/30 #{'hidden' if locked?}",
                  data: { exchange_lock_target: :lockBtn, action: "click->exchange-lock#lock" }
                ) { cached_icon :unlocked_padlock }

                button(
                  type: "button",
                  class: "p-1.5 rounded-md bg-green-100 text-black hover:bg-gray-100 border border-gray-300 " \
                         "dark:border-emerald-500/50 dark:bg-emerald-500/20 dark:text-emerald-200 dark:hover:bg-emerald-500/30 #{'hidden' unless locked?}",
                  data: { exchange_lock_target: :unlockBtn, action: "click->exchange-lock#unlock" }
                ) { cached_icon :locked_padlock }
              end
            end
          end

          button(type: :button, class: :hidden, tabindex: -1, data: { entity_transaction_target: "delExchange", action: "nested-form#remove" })
        end
      end

      def locked?
        exchange.effective_paid_state
      end

      def exchange_date_id
        parent_index = form.options[:parent_builder]&.index
        nested_index = [ parent_index, form.index ].compact.join("_")

        "exchange_date_#{nested_index}"
      end

      def exchange_border_class
        locked? ? "border-green-300 dark:border-emerald-500/40" : "border-red-300 dark:border-red-500/40"
      end

      def exchange_input_class(extra_classes)
        "#{extra_classes} w-full border border-gray-300 bg-gray-50 text-gray-900 text-sm rounded-lg p-2 " \
          "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500 dark:focus:border-sky-500/50 " \
          "read-only:cursor-not-allowed read-only:bg-gray-100 read-only:text-gray-500 read-only:opacity-70 dark:focus:ring-2 " \
          "dark:focus:ring-sky-500/60 dark:read-only:bg-slate-950 dark:read-only:text-slate-500"
      end
    end
  end
end
