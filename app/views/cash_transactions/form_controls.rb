# frozen_string_literal: true

class Views::CashTransactions::FormControls < Views::Base
  include CacheHelper
  include ComponentsHelper
  include TranslateHelper

  attr_reader :form, :cash_transaction, :user_bank_accounts, :categories, :entities

  def initialize(form:, cash_transaction:, user_bank_accounts:, categories:, entities:)
    @form = form
    @cash_transaction = cash_transaction
    @user_bank_accounts = user_bank_accounts
    @categories = categories
    @entities = entities
  end

  def view_template
    div(class: "lg:flex lg:gap-2 w-full mb-3") do
      user_bank_account_field
      category_and_entity_fields
      exchange_intent_field
      date_field
      price_and_installments_controls
    end
  end

  private

  def user_bank_account_field
    div(id: "cash_transaction_user_bank_account_combobox", class: "combobox-shell w-full lg:w-[16%] lg:flex-none mb-3 wallet-icon") do
      render Views::Shared::SingleSelectCombobox.new(
        name: "cash_transaction[user_bank_account_id]",
        options: user_bank_accounts.map { |label, value| [ label, value, {} ] },
        selected_value: cash_transaction.user_bank_account_id,
        placeholder: model_attribute(cash_transaction, :user_bank_account_id),
        input_data: {
          reactive_form_target: :input
        }
      )
    end
  end

  def category_and_entity_fields
    div(class: "flex w-full lg:flex-1 gap-2 mb-3 lg:mb-0 min-w-0") do
      div(id: "cash_transaction_category_combobox", class: "combobox-shell w-1/2 plus-icon", data: { reactive_form_target: :categoryCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :category_transaction,
          options: categories.map { |label, value| [ label, value, {} ] },
          selected_value: nil,
          placeholder: model_attribute(cash_transaction, :category_id),
          disabled: cash_transaction.card_payment? || cash_transaction.exchange_return?,
          input_data: {
            action: "change->reactive-form#insertCategory"
          }
        )
      end

      div(id: "cash_transaction_entity_combobox", class: "combobox-shell w-1/2 user-icon", data: { reactive_form_target: :entityCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :entity_transaction,
          options: entities.map { |label, value| [ label, value, {} ] },
          selected_value: nil,
          placeholder: model_attribute(cash_transaction, :entity_id),
          disabled: cash_transaction.card_payment? || cash_transaction.exchange_return?,
          input_data: {
            action: "change->reactive-form#insertEntity"
          }
        )
      end
    end
  end

  def date_field
    div(class: "w-full lg:w-[20%] lg:flex-none mb-3 lg:mb-0") do
      render Views::Shared::DatetimeInput.new(
        form:,
        field: :date,
        value: cash_transaction.date,
        id: :cash_transaction_date,
        hidden_data: {
          reactive_form_target: :dateInput
        },
        date_actions: "change->reactive-form#updateInstallmentsDates",
        time_actions: "change->reactive-form#updateInstallmentsDates",
        calendar: mobile?
      )
    end
  end

  def price_and_installments_controls
    positive = cash_transaction.price.to_i.positive?
    sign_bg_colour = positive ? "bg-green-300" : "bg-red-300"
    sign = positive ? "+" : "-"

    div(class: "flex w-full lg:w-[24%] lg:flex-none gap-1 mb-3 lg:mb-0") do
      Button(
        size: :lg,
        class: "w-1/12 #{sign_bg_colour} border border-black lg:hidden",
        tabindex: -1,
        title: action_message(:toggle_sign),
        disabled: cash_transaction.card_payment?,
        data: { action: "click->price-mask#toggleSign", target: ".sign-based" }
      ) { sign }

      div(class: "w-7/12 lg:w-7/12") do
        TextField \
          form, :price,
          inputmode: :numeric,
          svg: :money,
          id: :transaction_price,
          class: "sign-based font-graduate",
          autocomplete: :off,
          disabled: cash_transaction.card_payment?,
          data: { price_mask_target: :input,
                  controller: "input-select",
                  reactive_form_target: :priceInput,
                  action: "click->input-select#select input->price-mask#applyMask input->reactive-form#updateInstallmentsPrices",
                  sign: }
      end

      Button(
        size: :lg,
        class: "w-1/12 border border-black",
        tabindex: -1,
        title: action_message(:calculate_installments_price),
        disabled: cash_transaction.card_payment?,
        data: { action: "click->reactive-form#updateFullPrice" }
      ) { "=" }

      div(class: "w-3/12 lg:w-4/12") do
        TextFieldTag \
          :cash_installments_count,
          type: :number,
          svg: :number,
          min: 1, max: 72,
          value: [ visible_cash_installments_count, 1 ].max,
          class: "font-graduate",
          disabled: cash_transaction.card_payment?,
          data: { controller: "input-select",
                  reactive_form_target: :installmentsCountInput,
                  action: "click->input-select#select input->reactive-form#updateInstallmentsPrices" }
      end
    end
  end

  def exchange_intent_field
    div(
      class: "#{exchange_intent_wrapper_class} mb-3 lg:mb-0 hidden",
      data: { reactive_form_target: :exchangeIntentWrapper }
    ) do
      form.select(
        :friend_notification_intent,
        [
          [ model_attribute(cash_transaction, "friend_notification_intents.loan"), "loan" ],
          [ model_attribute(cash_transaction, "friend_notification_intents.reimbursement"), "reimbursement" ]
        ],
        { selected: cash_transaction.effective_friend_notification_intent.presence || "loan" },
        class: input_class_without_icon,
        data: { reactive_form_target: :exchangeIntentInput }
      )
    end
  end

  def exchange_intent_wrapper_class
    "w-full lg:w-2/12"
  end

  def visible_cash_installments_count
    cash_transaction.cash_installments.reject(&:marked_for_destruction?).size.presence || cash_transaction.cash_installments_count
  end
end
