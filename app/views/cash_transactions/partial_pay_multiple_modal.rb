# frozen_string_literal: true

class Views::CashTransactions::PartialPayMultipleModal < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::SelectTag

  include TranslateHelper
  include ComponentsHelper

  attr_reader :index_context, :modal_id

  def initialize(index_context:, modal_id: "cashInstallmentsPartialModal")
    @index_context = index_context
    @modal_id = modal_id
  end

  def view_template
    ModalShell(
      id: modal_id,
      title: I18n.t("bulk_actions.partial_pay.title"),
      options: {
        wrapper_data: {
          controller: "partial-pay-multiple",
          partial_pay_multiple_locale_value: I18n.locale
        }
      }
    ) do
      form_with(
        model: CashInstallment.new,
        url: partial_pay_multiple_cash_installments_path,
        method: :post,
        data: { controller: "price-mask", action: "submit->price-mask#removeMasks" }
      ) do |form|
        hidden_field_tag :ids, "", data: { bulk_ids_input: true, partial_pay_multiple_target: "idsInput" }
        hidden_field_tag :selection_json, "", data: { bulk_selection_input: true, partial_pay_multiple_target: "selectionInput" }
        hidden_field_tag :index_context_json, index_context.except(:available_subscriptions).to_json

        div(class: "space-y-4") do
          div(class: "rounded-lg bg-slate-50 px-4 py-3 text-sm text-slate-700") do
            div(class: "flex items-center justify-between gap-4") do
              span(class: "font-semibold") { I18n.t("bulk_actions.total_selected") }
              span(data: { partial_pay_multiple_target: "selectedTotal" }) { "R$0.00" }
            end

            div(class: "mt-2 flex items-center justify-between gap-4") do
              span(class: "font-semibold") { I18n.t("bulk_actions.partial_pay.allowed_range") }
              span(data: { partial_pay_multiple_target: "allowedRange" }) { "R$0.00 - R$0.00" }
            end
          end

          div(class: "mx-auto text-center") do
            bold_label(form, :price)

            TextField \
              form, :price,
              svg: :money,
              id: :partial_multiple_transaction_price,
              class: "font-graduate",
              value: 0,
              data: {
                controller: "input-select",
                price_mask_target: :input,
                partial_pay_multiple_target: "amountInput",
                action: "click->input-select#select input->price-mask#applyMask input->partial-pay-multiple#sync",
                sign: "+"
              }
          end

          div(class: "mx-auto text-center") do
            label(for: :partial_installment_id, class: "text-md font-poetsen-one font-thin") do
              I18n.t("bulk_actions.partial_pay.choose_installment")
            end

            select_tag(
              :partial_installment_id,
              "",
              id: :partial_installment_id,
              class: input_class_without_icon,
              required: true,
              data: {
                partial_pay_multiple_target: "installmentSelect",
                action: "change->partial-pay-multiple#sync"
              }
            )
          end

          div(class: "mx-auto text-center") do
            bold_label(form, :payment_date)

            render Views::Shared::DatetimeInput.new(
              form:,
              field: :date,
              value: Time.zone.now,
              id: "cash_installments_partial_payment_date",
              max_datetime: Time.zone.now.end_of_day
            )
          end

          p(class: "min-h-5 text-center text-sm text-red-600", data: { partial_pay_multiple_target: "message" }) { "" }

          div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
            form.submit I18n.t("confirmation.confirm"),
                        class: "bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded",
                        data: { modal_hide: modal_id, partial_pay_multiple_target: "submitButton" }

            button(
              class: "ml-2 bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded",
              type: :button,
              data: { modal_hide: modal_id }
            ) do
              I18n.t("confirmation.cancel")
            end
          end
        end
      end
    end
  end
end
