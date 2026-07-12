# frozen_string_literal: true

class Views::CashInstallments::PayModal < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :cash_installment, :index_context

  def initialize(cash_installment:, index_context: {})
    @cash_installment = cash_installment
    @index_context = index_context
  end

  def view_template
    cash_installment_date = cash_installment.date
    today = Time.zone.now
    diff = (today.to_date - cash_installment_date.to_date).to_i

    if diff.positive?
      cash_installment_date.strftime("%Y-%m-%dT%H:%M")
    else
      today.strftime("%Y-%m-%dT%H:%M")
    end => proposed_date

    div(
      id: "cashInstallmentModal_#{cash_installment.id}",
      class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)] bg-black/30",
      tabindex: "-1"
    ) do
      div(class: "bg-white p-6 rounded-lg shadow-lg dark:border dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:shadow-black/40") do
        div(class: "flex") do
          h1(class: "text-2xl mb-4 flex-1 text-start") { model_attribute(cash_installment, :confirm_payment) }

          button(
            type: :button,
            class: modal_close_button_class,
            data: { modal_hide: "cashInstallmentModal_#{cash_installment.id}" }
          ) do
            cached_icon(:little_x)
            span(class: "sr-only") do
              "Close modal"
            end
          end
        end
        form_with(
          model: cash_installment, url: pay_cash_installment_path(cash_installment.id),
          data: { controller: "price-mask", action: "submit->price-mask#removeMasks" }
        ) do |form|
          hidden_field_tag :index_context_json, index_context.to_json

          prices_range = [ -1, cash_installment.price ]
          positive = cash_installment.price.to_i.positive?
          prices_range[0] = 1 if positive
          sign = positive ? "+" : "-"

          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :price)

            TextField \
              form, :price,
              svg: :money,
              id: :transaction_price,
              class: "font-graduate",
              disabled: cash_installment.cash_transaction.card_payment? || cash_installment.cash_transaction.card_advance?,
              data: {
                controller: "input-select",
                price_mask_target: :input,
                action: "click->input-select#select input->price-mask#applyMask",
                sign:,
                min: prices_range.min,
                max: prices_range.max
              }
          end

          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :payment_date)

            render Views::Shared::DatetimeInput.new(
              form:,
              field: :date,
              value: Time.zone.parse(proposed_date),
              id: "cash_installment_#{cash_installment.id}_payment_date",
              autofocus: true,
              max_datetime: Time.zone.now.end_of_day
            )
          end

          div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
            form.submit I18n.t("confirmation.confirm"),
                        class: modal_confirm_button_class(:green),
                        data: { modal_hide: "cashInstallmentModal_#{cash_installment.id}" }

            button(
              class: modal_cancel_button_class,
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
