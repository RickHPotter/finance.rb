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
    div(id: "card_transaction_user_card_combobox", class: "combobox-shell w-full lg:w-2/12 mb-3 wallet-icon", data: { reactive_form_target: :userCardCombobox }) do
      render Views::Shared::SingleSelectCombobox.new(
        name: "card_transaction[user_card_id]",
        options: user_cards.map { |label, value| [ label, value, {} ] },
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
    div(class: "flex w-full lg:w-4/12 gap-2 mb-3 lg:mb-0") do
      div(id: "card_transaction_category_combobox", class: "combobox-shell lg:w-1/2 plus-icon", data: { reactive_form_target: :categoryCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :category_transaction,
          options: categories.map { |label, value| [ label, value, {} ] },
          selected_value: nil,
          placeholder: model_attribute(card_transaction, :category_id),
          autofocus: autofocus_target == :category_transaction,
          input_data: {
            action: "change->reactive-form#insertCategory"
          }
        )
      end

      div(id: "card_transaction_entity_combobox", class: "combobox-shell lg:w-1/2 user-icon", data: { reactive_form_target: :entityCombobox }) do
        render Views::Shared::SingleSelectCombobox.new(
          name: :entity_transaction,
          options: entities.map { |label, value| [ label, value, {} ] },
          selected_value: nil,
          placeholder: model_attribute(card_transaction, :entity_id),
          autofocus: autofocus_target == :entity_transaction,
          input_data: {
            action: "change->reactive-form#insertEntity"
          }
        )
      end
    end
  end

  def date_field
    div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
      render Views::Shared::DatetimeInput.new(
        form:,
        field: :date,
        value: card_transaction.date,
        id: :card_transaction_date,
        autofocus: autofocus_target == :date,
        hidden_data: {
          reactive_form_target: :dateInput,
          action: "change->reactive-form#requestSubmit"
        }
      )
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
