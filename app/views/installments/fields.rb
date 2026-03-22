# frozen_string_literal: true

module Views
  module Installments
    class Fields < Components::Base
      include CacheHelper

      attr_reader :form, :transactable, :installment

      def initialize(form:)
        @form = form
        @transactable = form.options[:parent_builder].object
        @installment = form.object
      end

      def view_template
        readonly = transactable.is_a?(CashTransaction) && (transactable.card_payment? || transactable.card_advance? || transactable.exchange_return?)

        div(
          class: "nested-form-wrapper bg-white border rounded-xl p-1 shadow-sm space-y-1 transition hover:shadow-md
                  #{locked? ? 'border-green-300' : 'border-red-300'} #{'hidden' if installment.marked_for_destruction?}",
          data: {
            new_record: installment.new_record?,
            reactive_form_target: "installmentWrapper",
            installment_lock_target: "installment",
            locked: locked?.to_s
          }
        ) do
          div(class: "flex justify-between items-center text-md font-medium bg-gray-100 border border-gray-200 rounded-lg px-2 py-1") do
            button(
              type: :button,
              class: "text-md rounded-md px-1 text-gray-700 hover:text-gray-900 transition",
              data: { action: "click->reactive-form#prevMonth" }
            ) { "←" }

            div(class: "flex items-center gap-2") do
              data = {}
              data = { action: "click->reactive-form#togglePaid" } if installment.installment_type == "CashInstallment"

              span(class: "installment_number_display text-gray-300") do
                installment.number
              end

              button(
                type: :button,
                class: "installment_paid_colour w-3 h-3 rounded-full  #{installment.paid ? 'bg-green-400' : 'bg-orange-600'} border border-white shadow-sm",
                data:
              )

              span(class: "installment_month_year text-gray-900", data: { reactive_form_target: :monthYearInstallment }) do
                installment.month_year if installment.month
              end
            end

            button(
              type: :button,
              class: "text-md rounded-md px-1 text-gray-700 hover:text-gray-900 transition",
              data: { action: "click->reactive-form#nextMonth" }
            ) { "→" }
          end

          div(class: "flex-1 grid gap-1") do
            form.text_field \
              :date,
              id: :installment_date,
              type: "datetime-local",
              value: installment.date&.strftime("%Y-%m-%dT%H:%M"),
              class: "installment_date w-full border border-gray-300 bg-gray-50 text-gray-900 text-sm rounded-lg p-2",
              data: { reactive_form_target: :dateInput, action: "input->reactive-form#setPaidIfPastCurrentDay" }

            positive = installment.price.to_i.positive?
            sign = positive ? "+" : "-"

            div(class: "flex gap-1") do
              form.text_field \
                :price,
                inputmode: :numeric,
                class: "sign-based price-input
                        w-full border border-gray-300 bg-gray-50 text-gray-900 text-sm rounded-lg p-2",
                readonly:,
                onclick: "this.select();",
                data: {
                  price_mask_target: :input,
                  reactive_form_target: :priceInstallmentInput,
                  installment_lock_target: :price,
                  action: "input->price-mask#applyMask",
                  sign:
                }

              div do
                button(
                  type: "button",
                  class: "p-1.5 rounded-md bg-red-300 hover:bg-gray-100 border border-gray-300 #{'hidden' if locked?}",
                  data: { installment_lock_target: :lockBtn, action: "click->installment-lock#lock" }
                ) { cached_icon :unlocked_padlock }

                button(
                  type: "button",
                  class: "p-1.5 rounded-md bg-green-100 hover:bg-gray-100 border border-gray-300 #{'hidden' unless locked?}",
                  data: { installment_lock_target: :unlockBtn, action: "click->installment-lock#unlock" }
                ) { cached_icon :locked_padlock }
              end
            end
          end

          form.check_box :paid, style: "display: none", class: :installment_paid

          form.hidden_field :number, class: :installment_number
          form.hidden_field :month, class: :installment_month
          form.hidden_field :year, class: :installment_year
          form.hidden_field :_destroy

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: "delInstallment", action: "nested-form#remove" })
        end
      end

      def locked?
        installment&.paid? || false
      end
    end
  end
end
