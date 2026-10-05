# frozen_string_literal: true

class Views::CashTransactions::FormControls < Views::Base
  include CacheHelper
  include ComponentsHelper
  include TranslateHelper

  attr_reader :form, :cash_transaction, :user_bank_accounts, :categories, :entities, :attachment_modal_id, :existing_count

  def initialize(form:, cash_transaction:, user_bank_accounts:, categories:, entities:, attachment_modal_id: nil, existing_count: 0)
    @form = form
    @cash_transaction = cash_transaction
    @user_bank_accounts = user_bank_accounts
    @categories = categories
    @entities = entities
    @attachment_modal_id = attachment_modal_id
    @existing_count = existing_count
  end

  def view_template
    div(class: "flex flex-col lg:flex-row lg:items-center lg:gap-2 w-full mb-3") do
      user_bank_account_field
      category_and_entity_fields
      exchange_intent_field
      date_field
      price_and_installments_controls
      attachments_button if attachment_modal_id
    end
  end

  private

  def user_bank_account_field
    div(id: "cash_transaction_user_bank_account_combobox", class: "combobox-shell w-full lg:w-[15%] lg:flex-none mb-3 lg:mb-0 wallet-icon") do
      render Views::Shared::SingleSelectCombobox.new(
        name: "cash_transaction[user_bank_account_id]",
        options: user_bank_accounts.map { |label, value, alias_data| [ label, value, alias_data || {} ] },
        selected_value: cash_transaction.user_bank_account_id,
        placeholder: model_attribute(cash_transaction, :user_bank_account_id),
        input_data: {
          reactive_form_target: :input
        }
      )
    end
  end

  def category_and_entity_fields
    composite = cash_transaction.composite?
    div(
      class: "flex w-full lg:w-[22%] lg:flex-none gap-1 mb-3 lg:mb-0 min-w-0 #{'pointer-events-none opacity-50' if composite}",
      data: { composite_transaction_target: "headerAllocations" }
    ) do
      div(id: "cash_transaction_category_combobox", class: "combobox-shell w-1/2 plus-icon", data: { reactive_form_target: :categoryCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :category_transaction,
          options: categories.map { |label, value, alias_data| [ label, value, alias_data || {} ] },
          selected_value: nil,
          placeholder: model_attribute(cash_transaction, :category_id),
          disabled: composite || cash_transaction.card_payment? || cash_transaction.exchange_return? || cash_transaction.generated_piggy_bank_return?,
          size: :sm,
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
          disabled: composite || cash_transaction.card_payment? || cash_transaction.exchange_return? || cash_transaction.generated_piggy_bank_return?,
          size: :sm,
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
        disabled: cash_transaction.generated_piggy_bank_return? && !cash_transaction.piggy_bank_return_open?,
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
    sign_bg_colour = positive ? "bg-green-300 dark:bg-green-400 dark:text-slate-950" : "bg-red-300 dark:bg-red-400 dark:text-slate-950"
    sign = positive ? "+" : "-"

    div(class: "flex w-full lg:flex-1 min-w-0 gap-1 mb-3 lg:mb-0 items-center") do
      Button(
        size: :lg,
        class: "w-8 shrink-0 #{sign_bg_colour} border border-black font-graduate dark:border-slate-700 dark:font-mono lg:hidden",
        tabindex: -1,
        title: action_message(:toggle_sign),
        disabled: cash_transaction.card_payment? || cash_transaction.generated_piggy_bank_return?,
        data: { action: "click->price-mask#toggleSign click->composite-transaction#recalculate", target: ".sign-based" }
      ) { sign }

      div(class: "flex-1 min-w-0") do
        TextField \
          form, :price,
          inputmode: :numeric,
          svg: :money,
          id: :transaction_price,
          class: "sign-based font-graduate dark:font-mono",
          autocomplete: :off,
          disabled: cash_transaction.card_payment? || cash_transaction.generated_piggy_bank_return?,
          data: { price_mask_target: :input,
                  controller: "input-select",
                  composite_transaction_target: :parentPrice,
                  reactive_form_target: :priceInput,
                  action: "click->input-select#select input->price-mask#applyMask input->composite-transaction#recalculate " \
                          "input->reactive-form#updateInstallmentsPrices input->reactive-form#syncPiggyBankDefault",
                  sign: }
      end

      Button(
        size: :lg,
        class: calculate_button_class,
        tabindex: -1,
        title: action_message(:calculate_installments_price),
        disabled: cash_transaction.card_payment? || cash_transaction.generated_piggy_bank_return?,
        data: { action: "click->reactive-form#updateFullPrice" }
      ) { "=" }

      div(class: "w-16 lg:w-20 shrink-0") do
        TextFieldTag \
          :cash_installments_count,
          type: :number,
          svg: :number,
          min: 1, max: 72,
          value: [ visible_cash_installments_count, 1 ].max,
          class: "font-graduate dark:font-mono",
          disabled: cash_transaction.card_payment? || cash_transaction.generated_piggy_bank_return?,
          data: { controller: "input-select",
                  reactive_form_target: :installmentsCountInput,
                  action: "click->input-select#select input->reactive-form#updateInstallmentsPrices" }
      end
    end
  end

  def attachments_button
    div(class: "w-full lg:w-auto mb-3 lg:mb-0 flex items-stretch shrink-0") do
      button(
        type: :button,
        class: "flex h-10 w-full lg:w-auto items-center justify-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-2 font-medium " \
               "text-slate-700 shadow-sm transition-colors hover:border-slate-400 hover:bg-slate-50 " \
               "dark:border-slate-700 dark:bg-slate-800/80 dark:text-slate-200 dark:hover:border-slate-600 dark:hover:bg-slate-800 cursor-pointer",
        title: I18n.t("attachments.title"),
        data: {
          modal_target: attachment_modal_id,
          modal_toggle: attachment_modal_id,
          action: "dragover->attachment-upload#dragOver dragleave->attachment-upload#dragLeave drop->attachment-upload#drop"
        }
      ) do
        span(class: "text-slate-500 dark:text-slate-400 shrink-0") { cached_icon(:paperclip) }
        span(
          class: "flex h-5 min-w-5 items-center justify-center rounded-full bg-slate-100 px-1 font-mono text-xs font-bold text-slate-700 " \
                 "border border-slate-200 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200",
          data: { attachment_upload_target: "counter" }
        ) { existing_count.to_s }
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
        {
          include_blank: true,
          selected: cash_transaction.effective_friend_notification_intent.presence || params.dig(:cash_transaction, :friend_notification_intent).presence
        },
        class: input_class_without_icon,
        data: { reactive_form_target: :exchangeIntentInput }
      )
    end
  end

  def exchange_intent_wrapper_class
    "w-full lg:w-2/12"
  end

  def calculate_button_class
    "w-9 shrink-0 flex items-center justify-center border border-black bg-white text-slate-950 dark:border-slate-600 dark:bg-transparent dark:text-slate-400 " \
      "dark:hover:bg-slate-800 dark:hover:text-slate-100 font-graduate dark:font-mono text-base"
  end

  def visible_cash_installments_count
    cash_transaction.cash_installments.reject(&:marked_for_destruction?).size.presence || cash_transaction.cash_installments_count
  end
end
