# frozen_string_literal: true

class Views::CardTransactions::FormControls < Views::Base
  include Phlex::Rails::Helpers::HiddenFieldTag

  include CacheHelper
  include ComponentsHelper
  include TranslateHelper

  attr_reader :form, :card_transaction, :user_cards, :categories, :entities, :autofocus_target, :user_card_date, :attachment_modal_id, :existing_count

  def initialize(
    form:, card_transaction:, user_cards:, categories:, entities:,
    autofocus_target:, user_card_date:, attachment_modal_id: nil, existing_count: 0
  )
    @form = form
    @card_transaction = card_transaction
    @user_cards = user_cards
    @categories = categories
    @entities = entities
    @autofocus_target = autofocus_target
    @user_card_date = user_card_date
    @attachment_modal_id = attachment_modal_id
    @existing_count = existing_count
  end

  def view_template
    hidden_field_tag :user_card_reference_date, user_card_date, disabled: true, type: "datetime-local", id: :cash_transaction_date

    div(class: "flex flex-col lg:flex-row lg:items-center lg:gap-2 w-full mb-3") do
      user_card_field
      category_and_entity_fields
      date_field
      price_and_installments_controls
      attachments_button if attachment_modal_id
    end
  end

  private

  def user_card_field
    div(id: "card_transaction_user_card_combobox", class: "combobox-shell w-full lg:w-[15%] lg:flex-none mb-3 lg:mb-0 wallet-icon",
        data: { reactive_form_target: :userCardCombobox }) do
      render Views::Shared::SingleSelectCombobox.new(
        name: "card_transaction[user_card_id]",
        options: user_cards.map { |label, value, alias_data| [ label, value, alias_data || {} ] },
        selected_value: card_transaction.user_card_id,
        placeholder: model_attribute(card_transaction, :user_card_id),
        input_data: {
          reactive_form_target: :input,
          action: "change->reactive-form#requestSubmitBasedOnUserCardChange"
        }
      )
    end
  end

  def category_and_entity_fields
    composite = card_transaction.composite?
    div(
      class: "flex w-full lg:w-[22%] lg:flex-none gap-1 mb-3 lg:mb-0 min-w-0 #{'pointer-events-none opacity-50' if composite}",
      data: { composite_transaction_target: "headerAllocations" }
    ) do
      div(id: "card_transaction_category_combobox", class: "combobox-shell w-1/2 plus-icon", data: { reactive_form_target: :categoryCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :category_transaction,
          options: categories.map { |label, value, alias_data| [ label, value, alias_data || {} ] },
          selected_value: nil,
          placeholder: model_attribute(card_transaction, :category_id),
          autofocus: autofocus_target == :category_transaction,
          disabled: composite,
          size: :sm,
          input_data: {
            action: "change->reactive-form#insertCategory"
          }
        )
      end

      div(id: "card_transaction_entity_combobox", class: "combobox-shell w-1/2 user-icon", data: { reactive_form_target: :entityCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :entity_transaction,
          options: entities.map { |label, value| [ label, value, {} ] },
          selected_value: nil,
          placeholder: model_attribute(card_transaction, :entity_id),
          autofocus: autofocus_target == :entity_transaction,
          disabled: composite,
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
        value: card_transaction.date,
        id: :card_transaction_date,
        autofocus: autofocus_target == :date,
        time_autofocus: autofocus_target == :time,
        hidden_data: {
          reactive_form_target: :dateInput
        },
        date_data: {
          next_autofocus: :time
        },
        date_actions: [
          "change->reactive-form#updateInstallmentsDates",
          mobile? ? "change->reactive-form#requestSubmit" : "blur->reactive-form#requestSubmit"
        ],
        time_actions: "change->reactive-form#updateInstallmentsDates",
        suppress_reactive_refresh_on_enter: true,
        calendar: mobile?
      )
    end
  end

  def price_and_installments_controls
    positive = card_transaction.price.to_i.positive?
    sign_bg_colour = positive ? "bg-green-300 dark:bg-green-400 dark:text-slate-950" : "bg-red-300 dark:bg-red-400 dark:text-slate-950"
    sign = positive ? "+" : "-"

    div(class: "flex w-full lg:flex-1 min-w-0 gap-1 mb-3 lg:mb-0 items-center") do
      Button(
        size: :lg,
        class: "w-8 shrink-0 #{sign_bg_colour} border border-black font-graduate dark:border-slate-700 dark:font-mono lg:hidden",
        tabindex: -1,
        title: action_message(:toggle_sign),
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
          data: {
            controller: "input-select",
            price_mask_target: :input,
            composite_transaction_target: :parentPrice,
            reactive_form_target: :priceInput,
            action: [
              "click->input-select#select",
              "input->price-mask#applyMask",
              "input->composite-transaction#recalculate",
              "input->reactive-form#updateInstallmentsPrices",
              "input->reactive-form#updateExchangeWhenDuplicating"
            ].join(" "),
            sign:
          }
      end

      Button(
        size: :lg,
        class: calculate_button_class,
        tabindex: -1,
        title: action_message(:calculate_installments_price),
        data: { action: "click->reactive-form#updateFullPrice" }
      ) { "=" }

      div(class: "w-16 lg:w-20 shrink-0") do
        TextFieldTag \
          :card_installments_count,
          type: :number,
          svg: :number,
          min: 1, max: 72,
          value: [ card_transaction.card_installments.size, card_transaction.card_installments_count, 1 ].max,
          class: "font-graduate dark:font-mono",
          data: {
            controller: "input-select",
            reactive_form_target: :installmentsCountInput,
            action: "click->input-select#select input->reactive-form#updateInstallmentsPrices input->reactive-form#updateExchangeWhenDuplicating"
          }
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

  def calculate_button_class
    "w-9 shrink-0 flex items-center justify-center border border-black bg-white text-slate-950 dark:border-slate-600 dark:bg-transparent dark:text-slate-400 " \
      "dark:hover:bg-slate-800 dark:hover:text-slate-100 font-graduate dark:font-mono text-base"
  end
end
