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
        price_readonly = transactable.is_a?(CashTransaction) && (transactable.card_payment? || transactable.card_advance?)

        div(
          class: "nested-form-wrapper space-y-1 rounded-xl border bg-white p-1 shadow-sm transition hover:shadow-md dark:rounded-lg dark:bg-slate-800
                  dark:hover:bg-slate-700/50 #{locked? ? 'border-green-300 dark:border-green-400/70' : 'border-red-300 dark:border-slate-700'}
                  #{'hidden' if installment.marked_for_destruction?}",
          data: {
            new_record: installment.new_record?,
            reactive_form_target: "installmentWrapper",
            installment_lock_target: "installment",
            locked: locked?.to_s
          }
        ) do
          div(class: header_class) do
            button(
              type: :button,
              class: "text-md rounded-md px-1 text-gray-700 transition hover:text-gray-900 dark:text-slate-400 dark:hover:text-slate-100",
              data: { action: "click->reactive-form#prevMonth" }
            ) { "←" }

            div(class: "flex items-center gap-2") do
              data = {}
              data = { action: "click->reactive-form#togglePaid" } if installment.installment_type == "CashInstallment"

              span(class: "installment_number_display text-gray-300 dark:font-mono dark:text-slate-600") do
                installment.number
              end

              button(
                type: :button,
                class: paid_dot_class,
                data:
              )

              span(class: "installment_month_year text-gray-900 dark:font-mono dark:text-xs dark:uppercase dark:tracking-wide dark:text-slate-400",
                   data: { reactive_form_target: :monthYearInstallment }) do
                installment.month_year if installment.month
              end
            end

            button(
              type: :button,
              class: "text-md rounded-md px-1 text-gray-700 transition hover:text-gray-900 dark:text-slate-400 dark:hover:text-slate-100",
              data: { action: "click->reactive-form#nextMonth" }
            ) { "→" }
          end

          div(class: "flex-1 grid gap-1") do
            render Views::Shared::DatetimeInput.new(
              form:,
              field: :date,
              value: installment.date,
              id: "installment_date_#{form.index}",
              hidden_class: "installment_date",
              hidden_data: installment_date_data,
              compact: true,
              readonly: locked?
            )

            positive = installment.price.to_i.positive?
            sign = positive ? "+" : "-"

            div(class: "flex gap-1") do
              form.text_field \
                :price,
                inputmode: :numeric,
                class: installment_input_class("sign-based price-input"),
                readonly: price_readonly,
                data: {
                  controller: "input-select",
                  price_mask_target: :input,
                  reactive_form_target: :priceInstallmentInput,
                  installment_lock_target: :price,
                  action: "click->input-select#select input->price-mask#applyMask",
                  sign:
                }

              div do
                button(
                  type: "button",
                  class: lock_button_class(hidden: locked?, locked: false),
                  data: { installment_lock_target: :lockBtn, action: "click->installment-lock#lock" }
                ) { cached_icon :unlocked_padlock }

                button(
                  type: "button",
                  class: lock_button_class(hidden: !locked?, locked: true),
                  data: { installment_lock_target: :unlockBtn, action: "click->installment-lock#unlock" }
                ) { cached_icon :locked_padlock }
              end
            end
          end

          form.check_box :paid, style: "display: none", class: :installment_paid

          form.hidden_field :id if installment.persisted?
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

      def installment_date_data
        data = { reactive_form_target: :dateInput }
        data[:action] = "input->reactive-form#setPaidIfPastCurrentDay" if installment.installment_type == "CashInstallment"
        data
      end

      def installment_input_class(prefix)
        "#{prefix} w-full rounded-lg border border-gray-300 bg-gray-50 p-2 text-sm text-gray-900 dark:rounded-md dark:border-slate-700 " \
          "dark:bg-slate-800 dark:font-mono dark:text-slate-100 dark:focus:border-sky-500/50 dark:focus:ring-2 dark:focus:ring-sky-500/60 " \
          "dark:focus:outline-none"
      end

      def header_class
        "text-md flex items-center justify-between rounded-lg border border-gray-200 bg-gray-100 px-2 py-1 font-medium " \
          "dark:border-slate-700 dark:bg-slate-900"
      end

      def paid_dot_class
        "installment_paid_colour h-3 w-3 rounded-full #{installment.paid ? 'bg-green-400' : 'bg-orange-600'} border border-white shadow-sm " \
          "dark:border-slate-900"
      end

      def lock_button_class(hidden:, locked:)
        base = "rounded-md border border-gray-300 p-1.5 text-black dark:border-slate-600 dark:bg-transparent dark:text-slate-400 " \
               "dark:hover:bg-slate-700 dark:hover:text-slate-100"
        colour = locked ? "bg-green-100 hover:bg-green-200" : "bg-red-300 hover:bg-red-200"

        "#{base} #{colour} #{'hidden' if hidden}"
      end
    end
  end
end
