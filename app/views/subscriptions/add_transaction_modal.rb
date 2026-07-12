# frozen_string_literal: true

class Views::Subscriptions::AddTransactionModal < Views::Base
  include Phlex::Rails::Helpers::RadioButtonTag
  include Phlex::Rails::Helpers::OptionsForSelect
  include Phlex::Rails::Helpers::SelectTag

  include TranslateHelper
  include ComponentsHelper

  attr_reader :user_cards, :user_bank_accounts, :user_card_options

  def initialize(user_cards:, user_bank_accounts:, user_card_options:)
    @user_cards = user_cards
    @user_bank_accounts = user_bank_accounts
    @user_card_options = user_card_options
  end

  def view_template
    ModalShell(
      id: "subscriptionAddTransactionModal",
      title: action_message(:newa),
      options: {
        close_button_data: { action: "subscription-transactions#closeModal" },
        wrapper_data: { action: "click->subscription-transactions#closeOnBackdrop" },
        content_data: { action: "click->subscription-transactions#ignoreBackdrop" }
      }
    ) do
      div(class: "grid grid-cols-1 gap-3 md:grid-cols-2", data: { controller: "price-mask", subscription_transactions_target: "modal" }) do
        div(class: "md:col-span-2 flex gap-4") do
          label(class: "flex items-center gap-2") do
            radio_button_tag :subscription_transaction_type, :cash, false,
                             data: { action: "subscription-transactions#changeType", subscription_transactions_target: "typeInput" }
            span { CashTransaction.model_name.human }
          end

          label(class: "flex items-center gap-2") do
            radio_button_tag :subscription_transaction_type, :card, true,
                             data: { action: "subscription-transactions#changeType", subscription_transactions_target: "typeInput" }
            span { CardTransaction.model_name.human }
          end
        end

        div do
          thin_label_text(model_attribute(Subscription, :interval_months).downcase)

          select_tag(
            :subscription_interval_months,
            id: :subscription_interval_months,
            class: modal_select_class,
            data: { action: "change->subscription-transactions#syncDates", subscription_transactions_target: "intervalInput" }
          ) do
            options_for_select(
              [
                [ model_attribute(Subscription, "intervals.monthly"), 1 ],
                [ model_attribute(Subscription, "intervals.every_2_months"), 2 ],
                [ model_attribute(Subscription, "intervals.every_3_months"), 3 ],
                [ model_attribute(Subscription, "intervals.every_6_months"), 6 ],
                [ model_attribute(Subscription, "intervals.yearly"), 12 ],
                [ model_attribute(Subscription, "intervals.every_2_years"), 24 ]
              ],
              1
            )
          end
        end

        div do
          thin_label_text(model_attribute(Subscription, :price).downcase)

          div(class: "flex items-center gap-1") do
            Button(
              type: :button,
              size: :lg,
              class: "w-1/6 border border-black bg-red-300 text-black dark:border-red-500 dark:bg-red-700/80 dark:text-white lg:hidden",
              tabindex: -1,
              title: action_message(:toggle_sign),
              data: { action: "click->price-mask#toggleSign", target: ".sign-based" }
            ) { "-" }

            div(class: "w-5/6 lg:w-full") do
              TextFieldTag(
                :subscription_modal_price,
                svg: :money,
                id: :subscription_modal_price,
                class: "sign-based font-graduate w-full",
                value: 0,
                required: true,
                data: {
                  controller: "input-select",
                  price_mask_target: :input,
                  action: "click->input-select#select input->price-mask#applyMask",
                  subscription_transactions_target: "priceInput",
                  sign: "-"
                }
              )
            end
          end
        end

        div do
          thin_label_text(model_attribute(Subscription, :start_month_year).downcase)

          TextFieldTag(
            :subscription_start_month_year,
            id: :subscription_start_month_year,
            type: :month,
            svg: :calendar,
            class: "font-graduate w-full",
            required: true,
            data: {
              action: "input->subscription-transactions#markStartMonthYearDirty input->subscription-transactions#syncDates",
              subscription_transactions_target: "startMonthYearInput"
            }
          )
        end

        div do
          thin_label_text(model_attribute(Subscription, :end_month_year).downcase)

          TextFieldTag(
            :subscription_end_month_year,
            id: :subscription_end_month_year,
            type: :month,
            svg: :calendar,
            class: "font-graduate w-full",
            required: true,
            data: {
              action: "input->subscription-transactions#markEndMonthYearDirty input->subscription-transactions#syncDates",
              subscription_transactions_target: "endMonthYearInput"
            }
          )
        end

        div do
          thin_label_text(model_attribute(CashTransaction, :date).downcase)

          TextFieldTag(
            :subscription_start_date,
            id: :subscription_start_date,
            type: :date,
            svg: :calendar,
            class: "font-graduate w-full",
            required: true,
            data: { action: "input->subscription-transactions#syncDates", subscription_transactions_target: "startDateInput" }
          )
        end

        div do
          thin_label_text(model_attribute(Subscription, :end_date).downcase)

          TextFieldTag(
            :subscription_end_date,
            id: :subscription_end_date,
            type: :date,
            svg: :calendar,
            class: "font-graduate w-full",
            disabled: true,
            data: { subscription_transactions_target: "endDateInput" }
          )
        end

        div(class: "md:col-span-2", data: { subscription_transactions_target: "cashAccountWrapper" }) do
          thin_label_text(model_attribute(CashTransaction, :user_bank_account_id).downcase)

          select_tag(
            :subscription_cash_account,
            id: :subscription_cash_account,
            class: modal_select_class,
            data: { subscription_transactions_target: "cashAccountInput" }
          ) do
            option(value: "") { model_attribute(CashTransaction, :user_bank_account_id) }
            options_for_select(user_bank_accounts)
          end
        end

        div(class: "md:col-span-2 hidden", data: { subscription_transactions_target: "cardWrapper" }) do
          thin_label_text(model_attribute(CardTransaction, :user_card_id).downcase)

          select_tag(
            :subscription_card,
            id: :subscription_card,
            class: modal_select_class,
            data: { action: "change->subscription-transactions#syncDates", subscription_transactions_target: "cardInput" }
          ) do
            option(value: "") { model_attribute(CardTransaction, :user_card_id) }
            options_for_select(user_card_options)
          end
        end

        div(class: "md:col-span-2 flex justify-end gap-2 pt-2") do
          button(
            type: :button,
            class: modal_confirm_button_class(:green),
            data: { action: "subscription-transactions#saveModalRows" }
          ) { I18n.t("confirmation.confirm") }

          button(
            type: :button,
            class: modal_cancel_button_class,
            data: { action: "subscription-transactions#closeModal" }
          ) { I18n.t("confirmation.cancel") }
        end
      end
    end
  end

  private

  def thin_label_text(text)
    span(class: "font-poetsen-one font-thin text-gray-500 dark:text-slate-400") { text }
  end

  def modal_select_class
    "w-full rounded-lg border border-slate-300 bg-white p-2 text-slate-900 disabled:cursor-not-allowed disabled:border-slate-200 " \
      "disabled:bg-slate-100 disabled:text-slate-400 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 " \
      "dark:disabled:border-slate-700 dark:disabled:bg-slate-900 dark:disabled:text-slate-500"
  end
end
