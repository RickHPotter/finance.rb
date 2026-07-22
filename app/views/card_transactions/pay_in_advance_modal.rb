# frozen_string_literal: true

class Views::CardTransactions::PayInAdvanceModal < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :month, :year, :user_card_id, :payment_window

  def initialize(month:, year:, user_card_id:, payment_window:)
    @month = month
    @year = year
    @user_card_id = user_card_id
    @payment_window = payment_window
  end

  def view_template
    modal_id = "cardTransactionModal_#{user_card_id}_#{month}_#{year}"
    date_input_id = "card_advance_date_#{user_card_id}_#{year}_#{month}"

    div(
      id: modal_id,
      class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
      tabindex: "-1"
    ) do
      div(class: "bg-white p-6 rounded-lg shadow-lg dark:border dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:shadow-black/40") do
        div(class: "flex") do
          h1(class: "text-2xl mb-4 flex-1 text-start text-slate-900 dark:text-slate-100") { model_attribute(CardTransaction, :confirm_payment) }

          button(
            type: :button,
            class: modal_close_button_class,
            data: { modal_hide: modal_id }
          ) do
            cached_icon(:little_x)

            span(class: "sr-only") do
              "Close modal"
            end
          end
        end
        form_with(
          model: CardTransaction.new,
          url: pay_in_advance_card_transactions_path,
          data: { controller: "price-mask", action: "submit->price-mask#removeMasks" }
        ) do |form|
          TextField form, :month, class: :hidden, value: month
          TextField form, :year, class: :hidden, value: year
          TextField form, :user_card_id, class: :hidden, value: user_card_id

          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :date, date_input_id)

            render Views::Shared::DatetimeInput.new(
              form:,
              field: :date,
              value: payment_window.default_datetime,
              id: date_input_id,
              min_datetime: payment_window.minimum,
              min_datetime_message: payment_window_message,
              max_datetime: payment_window.maximum,
              max_datetime_message: payment_window_message,
              autofocus: true
            )
          end

          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :price)

            TextField \
              form, :price,
              svg: :money,
              id: :transaction_price,
              class: "font-graduate dark:font-mono",
              value: 1,
              data: { controller: "input-select", price_mask_target: :input, action: "click->input-select#select input->price-mask#applyMask", min: 1 }
          end

          div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
            form.submit I18n.t("confirmation.confirm"),
                        class: "bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded",
                        data: { modal_hide: modal_id }

            button(
              class: cancel_button_class,
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

  private

  def payment_window_message
    I18n.t("card_advance.invalid_payment_window")
  end

  def cancel_button_class
    "ml-2 bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded " \
      "dark:border dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
