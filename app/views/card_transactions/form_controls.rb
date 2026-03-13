# frozen_string_literal: true

class Views::CardTransactions::FormControls < Views::Base
  include Phlex::Rails::Helpers::HiddenFieldTag

  include CacheHelper
  include ComponentsHelper
  include TranslateHelper

  attr_reader :form, :card_transaction, :user_cards, :categories, :entities, :autofocus_target, :user_card_date

  def initialize(form:, card_transaction:, user_cards:, categories:, entities:, autofocus_target:, user_card_date:) # rubocop:disable Metrics/ParameterLists
    @form = form
    @card_transaction = card_transaction
    @user_cards = user_cards
    @categories = categories
    @entities = entities
    @autofocus_target = autofocus_target
    @user_card_date = user_card_date
  end

  def view_template
    hidden_field_tag :user_card_reference_date, user_card_date, disabled: true, type: "datetime-local", id: :cash_transaction_date

    div(class: "lg:flex lg:gap-2 w-full mb-3") do
      user_card_field
      category_and_entity_fields
      date_field
      price_and_installments_controls
    end
  end

  private

  def user_card_field
    div(id: "hw_card_transaction_user_card_id", class: "hw-cb w-full lg:w-2/12 mb-3 wallet-icon") do
      form.combobox \
        :user_card_id,
        user_cards,
        mobile_at: "360px",
        render_in: { partial: "card_transactions/user_card" },
        include_blank: false,
        placeholder: model_attribute(card_transaction, :user_card_id),
        data: { reactive_form_target: :input, action: "hw-combobox:selection->reactive-form#requestSubmitBasedOnUserCardChange", value: ".hw-combobox__input" }
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
          placeholder: model_attribute(card_transaction, :category_id),
          autofocus: autofocus_target == :category_transaction,
          data: { action: "hw-combobox:selection->reactive-form#insertCategory", value: ".hw-combobox__input" }
      end

      div(id: "hw_entity_id", class: "hw-cb lg:w-1/2 user-icon") do
        combobox_tag \
          :entity_transaction,
          entities,
          mobile_at: "360px",
          include_blank: false,
          placeholder: model_attribute(card_transaction, :entity_id),
          autofocus: autofocus_target == :entity_transaction,
          data: { action: "hw-combobox:selection->reactive-form#insertEntity", value: ".hw-combobox__input" }
      end
    end
  end

  def date_field
    div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
      TextField \
        form, :date,
        id: :card_transaction_date,
        type: "datetime-local", svg: :calendar,
        value: card_transaction.date.strftime("%Y-%m-%dT%H:%M"),
        class: "font-graduate transaction-date",
        autofocus: autofocus_target == :date,
        data: { reactive_form_target: :dateInput, action: "focusin->reactive-form#setIniDate focusout->reactive-form#setEndDate" }
    end
  end

  def price_and_installments_controls
    positive = card_transaction.price.to_i.positive?
    sign_bg_colour = positive ? "bg-green-300" : "bg-red-300"
    sign = positive ? "+" : "-"

    div(class: "flex gap-1 mb-3 lg:mb-0") do
      Button(
        size: :lg,
        class: "w-1/12 #{sign_bg_colour} border border-black",
        tabindex: -1,
        title: action_message(:toggle_sign),
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
          data: {
            price_mask_target: :input,
            reactive_form_target: :priceInput,
            action: "input->price-mask#applyMask input->reactive-form#updateInstallmentsPrices input->reactive-form#updateExchangeWhenDuplicating",
            sign:
          }
      end

      Button(
        size: :lg,
        class: "w-1/12 border border-black",
        tabindex: -1,
        title: action_message(:calculate_installments_price),
        data: { action: "click->reactive-form#updateFullPrice" }
      ) { "=" }

      div(class: "w-4/12") do
        TextFieldTag \
          :card_installments_count,
          type: :number,
          svg: :number,
          min: 1, max: 72,
          value: [ card_transaction.card_installments.size, card_transaction.card_installments_count, 1 ].max,
          class: "font-graduate",
          onclick: "this.select();",
          data: {
            reactive_form_target: :installmentsCountInput,
            action: "input->reactive-form#updateInstallmentsPrices input->reactive-form#updateExchangeWhenDuplicating"
          }
      end
    end
  end
end
