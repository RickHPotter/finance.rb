# frozen_string_literal: true

class Views::CashInstallments::PayModal < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :cash_installment

  def initialize(cash_installment:)
    @cash_installment = cash_installment
  end

  def view_template
    div(
      id: "cashInstallmentModal_#{cash_installment.id}",
      class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
      tabindex: "-1"
    ) do
      div(class: "bg-white p-6 rounded-lg shadow-lg") do
        div(class: "flex") do
          h1(class: "text-2xl mb-4 flex-1 text-start") { model_attribute(cash_installment, :confirm_payment) }

          button(
            type: :button,
            class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
            data: { modal_hide: "cashInstallmentModal_#{cash_installment.id}" }
          ) do
            cached_icon(:little_x)
            span(class: "sr-only") do
              "Close modal"
            end
          end
        end
        form_with(model: cash_installment, url: pay_cash_installment_path(cash_installment.id)) do |form|
          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :payment_date)

            TextField \
              form, :date,
              type: "datetime-local",
              svg: :calendar,
              class: "font-graduate",
              max: Time.zone.now.strftime("%Y-%m-%dT%H:%M"),
              value: [ cash_installment.date&.strftime("%Y-%m-%dT%H:%M"), Time.zone.now.strftime("%Y-%m-%dT%H:%M") ].min
          end

          div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
            form.submit I18n.t("confirmation.confirm"),
                        class: "bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded",
                        data: { modal_hide: "cashInstallmentModal_#{cash_installment.id}" }

            button(
              class: "ml-2 bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded",
              type: :button,
              data: { modal_hide: "cashInstallmentModal_#{cash_installment.id}" }
            ) do
              I18n.t("confirmation.cancel")
            end
          end
        end
      end
    end
  end
end
