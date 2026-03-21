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
    div(id: "hw_cash_transaction_user_bank_account_id", class: "hw-cb w-full lg:w-2/12 mb-3 wallet-icon") do
      form.combobox \
        :user_bank_account_id,
        user_bank_accounts,
        mobile_at: "360px",
        include_blank: false,
        placeholder: model_attribute(cash_transaction, :user_bank_account_id),
        data: { reactive_form_target: :input }
    end
  end

  def category_and_entity_fields
    div(class: "flex w-full lg:w-4/12 gap-2 mb-3 lg:mb-0") do
      div(id: "hw_category_id", class: "hw-cb lg:w-1/2 plus-icon") do
        combobox_tag \
          :category_transaction,
          categories,
          mobile_at: "360px",
          include_blank: false,
          placeholder: model_attribute(cash_transaction, :category_id),
          disabled: cash_transaction.card_payment? || cash_transaction.exchange_return?,
          data: { action: "hw-combobox:selection->reactive-form#insertCategory", value: ".hw-combobox__input" }
      end

      div(id: "hw_entity_id", class: "hw-cb lg:w-1/2 user-icon") do
        combobox_tag \
          :entity_transaction,
          entities,
          mobile_at: "360px",
          include_blank: false,
          placeholder: model_attribute(cash_transaction, :entity_id),
          disabled: cash_transaction.card_payment? || cash_transaction.exchange_return?,
          data: { action: "hw-combobox:selection->reactive-form#insertEntity", value: ".hw-combobox__input" }
      end
    end
  end

  def date_field
    div(class: "w-full lg:w-2/12 mb-3 lg:mb-0") do
      TextField \
        form, :date,
        id: :cash_transaction_date,
        type: "datetime-local", svg: :calendar,
        value: cash_transaction.date.strftime("%Y-%m-%dT%H:%M"),
        class: "font-graduate transaction-date",
        data: { reactive_form_target: :dateInput, action: "change->reactive-form#updateInstallmentsDates" }
    end
  end

  def price_and_installments_controls
    positive = cash_transaction.price.to_i.positive?
    sign_bg_colour = positive ? "bg-green-300" : "bg-red-300"
    sign = positive ? "+" : "-"

    div(class: "flex gap-1 mb-3 lg:mb-0") do
      Button(
        size: :lg,
        class: "w-1/12 #{sign_bg_colour} border border-black",
        tabindex: -1,
        title: action_message(:toggle_sign),
        disabled: cash_transaction.card_payment?,
        data: { action: "click->price-mask#toggleSign", target: ".sign-based" }
      ) { sign }

      div(class: "w-6/12") do
        TextField \
          form, :price,
          inputmode: :numeric,
          svg: :money,
          id: :transaction_price,
          class: "sign-based font-graduate",
          autocomplete: :off,
          onclick: "this.select();",
          disabled: cash_transaction.card_payment?,
          data: { price_mask_target: :input,
                  reactive_form_target: :priceInput,
                  action: "input->price-mask#applyMask input->reactive-form#updateInstallmentsPrices",
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

      div(class: "w-4/12") do
        TextFieldTag \
          :cash_installments_count,
          type: :number,
          svg: :number,
          min: 1, max: 72,
          value: [ visible_cash_installments_count, 1 ].max,
          class: "font-graduate",
          onclick: "this.select();",
          disabled: cash_transaction.card_payment?,
          data: { reactive_form_target: :installmentsCountInput, action: "input->reactive-form#updateInstallmentsPrices" }
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
