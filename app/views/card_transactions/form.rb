# frozen_string_literal: true

module Views
  module CardTransactions
    class Form < Components::Base
      include Phlex::Rails::Helpers::TurboFrameTag
      include Phlex::Rails::Helpers::FormWith
      include Phlex::Rails::Helpers::TextFieldTag
      include Phlex::Rails::Helpers::HiddenFieldTag
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::DOMID
      include TranslateHelper
      include ComponentsHelper
      include CacheHelper
      include ContextHelper

      attr_reader :current_user, :user_card, :card_transaction

      def initialize(current_user:, card_transaction:)
        @current_user = current_user
        @card_transaction = card_transaction
        @user_card = card_transaction&.user_card
        @due_date = @user_card&.calculate_reference_date(Date.current)
        @closing_date = @due_date - @user_card.days_until_due_date if @due_date

        set_cards
        set_user_cards
        set_categories
        set_entities
      end

      def view_template
        turbo_frame_tag dom_id @card_transaction do
          form_with model: card_transaction,
                    id: :transaction_form,
                    class: "contents text-black",
                    data: { controller: "form-validate reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
            form.hidden_field :user_id, value: current_user.id

            # FIXME: try to find a cleaner way to do this
            hidden_field_tag :days_until_due_date,  user_card&.days_until_due_date, disabled: true, data: { reactive_form_target: :daysUntilDueDate }
            hidden_field_tag :closing_date_day,     @closing_date&.day,             disabled: true, data: { reactive_form_target: :closingDateDay }
            hidden_field_tag :category_colours,     categories_json,                disabled: true, data: { reactive_form_target: :categoryColours }
            hidden_field_tag :entity_icons,         entities_json,                  disabled: true, data: { reactive_form_target: :entityIcons }
            hidden_field_tag :exchange_category_id, exchange_category_id,           disabled: true, id: :exchange_category_id

            div(class: "w-full mb-6") do
              form.text_field :description,
                              class: outdoor_input_class,
                              autofocus: true,
                              autocomplete: :off,
                              data: { controller: "blinking-placeholder", text: model_attribute(card_transaction, :description) }
            end

            div(class: "w-full mb-6") do
              render_icon :quote
              form.text_area \
                :comment,
                class: "text-gray-500 p-4 ps-9 w-full border-1 border-gray-400 shadow-lg rounded-lg focus:ring-transparent focus:outline-none caret-transparent",
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
                form.combobox \
                  :category_transaction,
                  @categories,
                  mobile_at: "360px",
                  include_blank: false,
                  placeholder: model_attribute(card_transaction, :category_id),
                  data: { action: "hw-combobox:selection->reactive-form#insertCategory", value: ".hw-combobox__input" }
              end

              div(id: "hw_entity_id", class: "hw-cb w-full lg:w-2/12 mb-3 user-icon") do
                form.combobox \
                  :entity_transaction,
                  @entities,
                  mobile_at: "360px",
                  include_blank: false,
                  placeholder: model_attribute(card_transaction, :entity_id),
                  data: { action: "hw-combobox:selection->reactive-form#insertEntity", value: ".hw-combobox__input" }
              end

              div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
                TextField \
                  form, :date,
                  id: :card_transaction_date,
                  type: "datetime-local", svg: :calendar,
                  value: card_transaction.date.strftime("%Y-%m-%dT%H:%M"),
                  class: "font-graduate",
                  data: { controller: "ruby-ui--calendar-input", reactive_form_target: :dateInput, action: "change->reactive-form#updateInstallmentsDates" }
              end

              div(class: "flex") do
                div(class: "w-2/3 lg:w-3/5 mb-3 lg:mb-0") do
                  TextField \
                    form, :price,
                    svg: :money,
                    id: :transaction_price,
                    class: "font-graduate",
                    data: { price_mask_target: :input,
                            reactive_form_target: :priceInput,
                            action: "input->price-mask#applyMask input->reactive-form#updateInstallmentsPrices" }
                end

                div(class: "w-1/3 lg:w-2/5") do
                  TextField \
                    form, :card_installments_count,
                    type: :number,
                    svg: :number,
                    min: 1, max: 72,
                    value: [ card_transaction.card_installments.size, card_transaction.card_installments_count, 1 ].max,
                    class: "font-graduate",
                    data: { reactive_form_target: :installmentsCountInput, action: "input->reactive-form#updateInstallmentsPrices" }
                end
              end
            end

            # Installments
            div(class: "grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-3 pb-3",
                data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
              template(data: { nested_form_target: "template" }) do
                form.fields_for :card_installments, CardInstallment.new, child_index: "NEW_RECORD" do |installment_fields|
                  render partial "installments/installment_fields", form: installment_fields
                end
              end

              form.fields_for :card_installments do |installment_fields|
                render partial "installments/installment_fields", form: installment_fields
              end

              div(data: { nested_form_target: "target" })

              button(class: :hidden, data: { reactive_form_target: :addInstallment, action: "nested-form#add" })
            end

            # Categories
            div(id: "categories_nested", class: "flex gap-2 overflow-x-auto pb-3",
                data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
              template(data: { nested_form_target: "template" }) do
                form.fields_for :category_transactions, CategoryTransaction.new, child_index: "NEW_RECORD" do |category_transaction_fields|
                  render partial "category_transactions/category_transaction_fields", form: category_transaction_fields
                end
              end

              category_transactions_association = card_transaction.category_transactions.includes(:category) if card_transaction.category_transactions.count > 1
              form.fields_for :category_transactions, category_transactions_association do |category_transaction_fields|
                render partial "category_transactions/category_transaction_fields", form: category_transaction_fields
              end

              div(data: { nested_form_target: "target" })

              button(class: :hidden, data: { reactive_form_target: :addCategory, action: "nested-form#add" })
            end

            # Entities
            div(id: "entities_nested", class: "flex gap-2 overflow-x-auto pb-3",
                data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
              template(data: { nested_form_target: "template" }) do
                form.fields_for :entity_transactions, EntityTransaction.new, child_index: "NEW_RECORD" do |entity_transaction_fields|
                  render ::Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
                end
              end

              if card_transaction.entity_transactions.count > 1
                entity_transactions_association = card_transaction.entity_transactions.includes(:entity,
                                                                                                :exchanges)
              end
              form.fields_for :entity_transactions, entity_transactions_association do |entity_transaction_fields|
                render ::Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
              end

              div(data: { nested_form_target: "target" })

              button(class: :hidden, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
            end

            render Components::ButtonComponent.new form:, options: { label: action_model(:submit, card_transaction) }

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

      def exchange_category_id
        current_user.built_in_category("EXCHANGE").id
      end
    end
  end
end
