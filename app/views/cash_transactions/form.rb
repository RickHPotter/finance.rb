# frozen_string_literal: true

class Views::CashTransactions::Form < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :cash_transaction

  def initialize(current_user:, cash_transaction:)
    @current_user = current_user
    @cash_transaction = cash_transaction

    set_banks
    set_user_bank_accounts
    set_categories
    set_entities
  end

  def view_template
    turbo_frame_tag dom_id @cash_transaction do
      form_with model: cash_transaction,
                id: :transaction_form,
                class: "contents text-black",
                data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
        form.hidden_field :user_id, value: current_user.id
        hidden_field_tag :category_colours,       categories_json,        disabled: true, data: { reactive_form_target: :categoryColours }
        hidden_field_tag :entity_icons,           entities_json,          disabled: true, data: { reactive_form_target: :entityIcons }
        hidden_field_tag :exchange_category_id,   exchange_category.id,   disabled: true, id: :exchange_category_id
        hidden_field_tag :exchange_category_name, exchange_category.name, disabled: true, id: :exchange_category_name

        div(class: "w-full mb-6") do
          form.text_field :description,
                          class: outdoor_input_class,
                          autofocus: true,
                          autocomplete: :off,
                          data: { controller: "blinking-placeholder", text: model_attribute(cash_transaction, :description) }
        end

        div(class: "w-full mb-6") do
          cached_icon :quote
          form.text_area \
            :comment,
            class: "text-gray-500 p-4 ps-9 w-full border-1 border-gray-400 shadow-lg rounded-lg focus:ring-transparent focus:outline-none caret-transparent",
            data: { controller: "text-area-autogrow blinking-placeholder", text: model_attribute(cash_transaction, :comment_placeholder) }
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "hw_cash_transaction_user_bank_account_id", class: "hw-cb w-full lg:w-2/12 mb-3 wallet-icon") do
            form.combobox \
              :user_bank_account_id,
              @user_bank_accounts,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(cash_transaction, :user_bank_account_id),
              data: { reactive_form_target: :input }
          end

          div(id: "hw_category_id", class: "hw-cb w-full lg:w-2/12 mb-3 plus-icon") do
            combobox_tag \
              :category_transaction,
              @categories,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(cash_transaction, :category_id),
              disabled: cash_transaction.exchange_return?,
              data: { action: "hw-combobox:selection->reactive-form#insertCategory", value: ".hw-combobox__input" }
          end

          div(id: "hw_entity_id", class: "hw-cb w-full lg:w-2/12 mb-3 user-icon") do
            combobox_tag \
              :entity_transaction,
              @entities,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(cash_transaction, :entity_id),
              disabled: cash_transaction.exchange_return?,
              data: { action: "hw-combobox:selection->reactive-form#insertEntity", value: ".hw-combobox__input" }
          end

          div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
            TextField \
              form, :date,
              id: :cash_transaction_date,
              type: "datetime-local", svg: :calendar,
              value: cash_transaction.date.strftime("%Y-%m-%dT%H:%M"),
              class: "font-graduate",
              data: { controller: "ruby-ui--calendar-input", reactive_form_target: :dateInput, action: "change->reactive-form#updateInstallmentsDates" }
          end

          positive = cash_transaction.price.to_i.positive?
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
                :cash_installments_count,
                type: :number,
                svg: :number,
                min: 1, max: 72,
                value: [ cash_transaction.cash_installments.size, cash_transaction.cash_installments_count, 1 ].max,
                class: "font-graduate",
                onclick: "this.select();",
                data: { reactive_form_target: :installmentsCountInput, action: "input->reactive-form#updateInstallmentsPrices" }
            end
          end
        end

        div(class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data: { nested_form_target: "template" }) do
            form.fields_for :cash_installments, CashInstallment.new, child_index: "NEW_RECORD" do |installment_fields|
              render Views::Installments::Fields.new(form: installment_fields)
            end
          end

          cash_installments = cash_transaction.new_record? ? cash_transaction.cash_installments : cash_transaction.cash_installments.order(:date, :number)
          form.fields_for :cash_installments, cash_installments do |installment_fields|
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

          category_transactions_association = cash_transaction.category_transactions.includes(:category) if cash_transaction.category_transactions.count > 1
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

          if cash_transaction.entity_transactions.count > 1
            entity_transactions_association = cash_transaction.entity_transactions.includes(:entity,
                                                                                            :exchanges)
          end
          form.fields_for :entity_transactions, entity_transactions_association do |entity_transaction_fields|
            render Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
          end

          div(data: { nested_form_target: "target" })

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
        end

        div(class: "grid grid-cols-1 lg:flex items-center justify-center gap-2 mx-auto") do
          Button(type: :submit, variant: :purple) { action_model(:submit, cash_transaction) }

          if cash_transaction.can_be_destroyed?
            Button(
              id: "delete_cash_transaction_#{cash_transaction.id}",
              type: :submit,
              variant: :destructive,
              link: cash_transaction_path(cash_transaction),
              data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
            ) do
              action_model(:destroy, cash_transaction)
            end
          end

          card_transactions_sheet if cash_transaction.exchange_return?
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

  def card_transactions_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, class: "w-full") do
          action_model(:index, CardTransaction, 2)
        end
      end

      SheetContent(side: :middle, class: "w-full md:w-1/3 max-h-[90vh] flex flex-col") do
        SheetHeader do
          SheetTitle { pluralise_model(CardTransaction, 2) }
          SheetDescription do
            span { current_user.built_in_category("EXCHANGE RETURN").name }
          end
        end

        SheetMiddle(class: "overflow-y-auto flex-1") do
          SheetMiddle do
            card_transactions = cash_transaction.exchanges.map(&:entity_transaction).map(&:transactable)
            years = [ card_transactions.map(&:year).uniq ]

            index_context = {
              current_user:,
              years:,
              default_year: years.last,
              active_month_years: card_transactions.map { |ct| Date.new(ct.year, ct.month).strftime("%Y%m").to_i }.sort.uniq,
              search_term: "",
              card_installment_ids: current_user.card_installments.where(card_transaction_id: card_transactions.pluck(:id)).order(:date, :id).pluck(:id),
              category_id: [ exchange_category.id ],
              entity_id: cash_transaction.entities.pluck(:id),
              user_bank_account_id: nil,
              from_ct_price: nil,
              to_ct_price: nil,
              from_price: nil,
              to_price: nil,
              from_installments_count: nil,
              to_installments_count: nil,
              user_card: nil,
              skip_budgets: true,
              force_mobile: true
            }

            render Views::CardTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end
end
