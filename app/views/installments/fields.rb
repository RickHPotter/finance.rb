# frozen_string_literal: true

module Views
  module Installments
    class Fields < Components::Base
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::ImageTag

      include CacheHelper

      attr_reader :form, :installment

      def initialize(form:)
        @form = form
        @installment = form.object
      end

      def view_template
        div(class: "nested-form-wrapper", data: { new_record: installment.new_record?, reactive_form_target: "installmentWrapper" }) do
          span(class: "flex justify-between items-center text-sm font-medium text-black mx-auto bg-gray-200 border border-gray-300 rounded-sm") do
            button(
              type: :button,
              class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-500 px-1",
              data: { action: "click->reactive-form#prevMonth" }
            ) do
              "←"
            end

            div(class: "col-span-4 flex items-center") do
              button(type: :button, class: "flex w-3 h-3 rounded-full me-2 flex-shrink-0 #{installment.paid ? 'bg-green-400' : 'bg-orange-600'}")

              span(class: "installment_month_year font-victor font-semibold text-orange-950", data: { reactive_form_target: :monthYearInstallment }) do
                installment.month_year if installment.month
              end
            end

            button(
              type: :button,
              class: "text-lg font-bold rounded-sm shadow-sm bg-transparent border-1 border-purple-500 px-1",
              data: { action: "click->reactive-form#nextMonth" }
            ) do
              "→"
            end
          end

          div(class: "grid grid-cols-3 w-full") do
            div(class: "col-span-2") do
              div(class: "flex justify-center items-center text-sm text-gray-900 bg-gray-200 border border-gray-300 cursor-pointer rounded-none rounded-s-lg") do
                form.text_field \
                  :date,
                  id: :installment_date,
                  type: "datetime-local",
                  value: installment.date&.strftime("%Y-%m-%dT%H:%M"),
                  class: "installment_date w-full outline-hidden appearance-none bg-transparent border-0 font-graduate text-[0.8rem]",
                  data: { reactive_form_target: :dateInput }
              end
            end

            positive = installment.price.to_i.positive?
            sign = positive ? "+" : "-"

            form.text_field \
              :price,
              class: "sign-based price-input rounded-none rounded-e-lg bg-gray-50 border border-gray-300 text-gray-900 focus:ring-blue-500 focus:border-blue-500
                      block flex-1 min-w-0 w-full text-sm p-2.5",
              data: { price_mask_target: :input, reactive_form_target: :priceInstallmentInput, action: "input->price-mask#applyMask", sign: }
          end

          form.hidden_field :number, class: :installment_number
          form.hidden_field :month, class: :installment_month
          form.hidden_field :year, class: :installment_year
          form.hidden_field :_destroy

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: "delInstallment", action: "nested-form#remove" })
        end
      end
    end
  end
end
