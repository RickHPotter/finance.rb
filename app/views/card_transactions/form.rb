# frozen_string_literal: true

class Views::CardTransactions::Form < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Views::CardTransactions

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :card_transaction

  def initialize(current_user:, card_transaction:)
    @current_user = current_user
    @card_transaction = card_transaction

    set_cards
    set_user_cards
    set_categories
    set_entities

    @user_cards << card_transaction.user_card.slice(:user_card_name, :id).values if card_transaction.user_card.inactive?
  end

  def view_template
    user_card_date = card_transaction.user_card.calculate_reference_date(card_transaction.date).to_datetime

    turbo_frame_tag dom_id @card_transaction do
      form_with model: card_transaction,
                id: :transaction_form,
                class: "contents text-black",
                data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
        form.hidden_field :user_id, value: current_user.id

        hidden_field_tag :category_colours, categories_json, disabled: true, data: { reactive_form_target: :categoryColours }
        hidden_field_tag :entity_icons,     entities_json,   disabled: true, data: { reactive_form_target: :entityIcons }

        hidden_field_tag :exchange_category_id,   exchange_category.id,   disabled: true, id: :exchange_category_id
        hidden_field_tag :exchange_category_name, exchange_category.name, disabled: true, id: :exchange_category_name

        hidden_field_tag :user_card_reference_date, user_card_date, disabled: true, type: "datetime-local", id: :cash_transaction_date

        div(class: "w-full mb-6") do
          form.text_field :description,
                          class: outdoor_input_class,
                          autofocus: params[:commit] != "Update",
                          autocomplete: :off,
                          data: { controller: "blinking-placeholder", text: model_attribute(card_transaction, :description) }
        end

        div(class: "w-full mb-6") do
          cached_icon :quote
          form.text_area \
            :comment,
            class: "text-gray-500 p-4 ps-9 w-full border-1 border-gray-400 shadow-lg rounded-lg focus:ring-transparent focus:outline-none",
            data: { controller: "text-area-autogrow blinking-placeholder", text: model_attribute(card_transaction, :comment_placeholder) }
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "hw_card_transaction_user_card_id", class: "hw-cb w-full lg:w-2/12 mb-3 wallet-icon") do
            form.combobox \
              :user_card_id,
              @user_cards,
              mobile_at: "360px",
              render_in: { partial: "card_transactions/user_card" },
              include_blank: false,
              placeholder: model_attribute(card_transaction, :user_card_id),
              data: { reactive_form_target: :input, action: "hw-combobox:selection->reactive-form#requestSubmit", value: ".hw-combobox__input" }
          end

          div(id: "hw_category_id", class: "hw-cb w-full lg:w-2/12 mb-3 plus-icon") do
            combobox_tag \
              :category_transaction,
              @categories,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(card_transaction, :category_id),
              autofocus: params[:commit] == "Update" && card_transaction.category_transactions.empty?,
              data: { action: "hw-combobox:selection->reactive-form#insertCategory", value: ".hw-combobox__input" }
          end

          div(id: "hw_entity_id", class: "hw-cb w-full lg:w-2/12 mb-3 user-icon") do
            combobox_tag \
              :entity_transaction,
              @entities,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(card_transaction, :entity_id),
              autofocus: params[:commit] == "Update" && card_transaction.category_transactions.any? && card_transaction.entity_transactions.empty?,
              data: { action: "hw-combobox:selection->reactive-form#insertEntity", value: ".hw-combobox__input" }
          end

          div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
            TextField \
              form, :date,
              id: :card_transaction_date,
              type: "datetime-local", svg: :calendar,
              value: card_transaction.date.strftime("%Y-%m-%dT%H:%M"),
              class: "font-graduate transaction-date",
              data: { reactive_form_target: :dateInput, action: "focusout->reactive-form#requestSubmit" }
          end

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
                data: { reactive_form_target: :installmentsCountInput, action: "input->reactive-form#updateInstallmentsPrices" }
            end
          end
        end

        div(class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data: { nested_form_target: "template" }) do
            form.fields_for :card_installments, CardInstallment.new, child_index: "NEW_RECORD" do |installment_fields|
              render Views::Installments::Fields.new(form: installment_fields)
            end
          end

          card_installments = card_transaction.new_record? ? card_transaction.card_installments : card_transaction.card_installments.order(:date, :number)
          form.fields_for :card_installments, card_installments do |installment_fields|
            render Views::Installments::Fields.new(form: installment_fields)
          end

          div(data: { nested_form_target: "target" })

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addInstallment, action: "nested-form#add" })
        end

        div(id: "categories_nested", class: "flex gap-2 overflow-x-auto pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data: { nested_form_target: "template" }) do
            form.fields_for :category_transactions, CategoryTransaction.new, child_index: "NEW_RECORD" do |category_transaction_fields|
              render Views::CategoryTransactions::Fields.new(form: category_transaction_fields)
            end
          end

          category_transactions_association = card_transaction.category_transactions.includes(:category) if card_transaction.category_transactions.count > 1
          form.fields_for :category_transactions, category_transactions_association do |category_transaction_fields|
            render Views::CategoryTransactions::Fields.new(form: category_transaction_fields)
          end

          div(data: { nested_form_target: "target" })

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addCategory, action: "nested-form#add" })
        end

        div(id: "entities_nested", class: "flex gap-2 overflow-x-auto pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data: { nested_form_target: "template" }) do
            form.fields_for :entity_transactions, EntityTransaction.new, child_index: "NEW_RECORD" do |entity_transaction_fields|
              render Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
            end
          end

          entity_transactions_association = card_transaction.entity_transactions.includes(:entity, :exchanges) if card_transaction.entity_transactions.count > 1
          form.fields_for :entity_transactions, entity_transactions_association do |entity_transaction_fields|
            render Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
          end

          div(data: { nested_form_target: "target" })

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
        end

        div(class: "w-full my-2") do
          Button(type: :submit, variant: :purple) { action_model(:submit, card_transaction) }
        end

        if card_transaction.can_be_destroyed?
          div(class: "w-full mb-2") do
            Button(
              link: duplicate_card_transaction_path(card_transaction),
              data: { turbo_frame: "center_container" }
            ) do
              action_model(:duplicate, card_transaction)
            end
          end

          div(class: "w-full") do
            Button(
              id: "delete_card_transaction_#{card_transaction.id}",
              type: :submit,
              variant: :destructive,
              link: card_transaction_path(card_transaction),
              data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
            ) do
              action_model(:destroy, card_transaction)
            end
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  def categories_json
    current_user.categories.to_h do |c|
      [ c.id, c.bg_colour ]
    end.to_json
  end

  def entities_json
    current_user.entities.to_h do |c|
      [ c.id, asset_path("avatars/#{c.avatar_name}") ]
    end.to_json
  end

  def exchange_category
    current_user.built_in_category("EXCHANGE")
  end
end
