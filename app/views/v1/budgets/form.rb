# frozen_string_literal: true

class Views::V1::Budgets::Form < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Views::V1::Budgets

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :budget, :entities

  def initialize(current_user:, budget:)
    @current_user = current_user
    @budget = budget

    set_categories
    set_entities
  end

  def view_template
    turbo_frame_tag dom_id budget do
      form_with(
        model: budget,
        id: :form,
        class: "contents text-black",
        data: { controller: "reactive-form price-mask dynamic-description", action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        hidden_field_tag :category_colours, categories_json, disabled: true, data: { reactive_form_target: :categoryColours }
        hidden_field_tag :entity_icons,     entities_json,   disabled: true, data: { reactive_form_target: :entityIcons }

        div(class: "w-full mb-6") do
          form.text_field \
            :description,
            autocomplete: :off,
            class: outdoor_readonly_input_class,
            data: { controller: "blinking-placeholder", text: model_attribute(budget, :description), dynamic_description_target: :description }
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "hw_category_id", class: "hw-cb w-full lg:w-1/4 mb-3 plus-icon") do
            bold_label(form, :categories)
            raw form.combobox \
              :budget_category, @categories,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(budget, :category_id),
              data: { action: "hw-combobox:selection->reactive-form#insertCategory hw-combobox:selection->dynamic-description#updateDescription",
                      value: ".hw-combobox__input" }
          end

          div(id: "hw_entity_id", class: "hw-cb w-full lg:w-1/4 mb-3 user-icon") do
            bold_label(form, :entities)
            raw form.combobox \
              :budget_entity,
              @entities,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(budget, :entity_id),
              data: { action: "hw-combobox:selection->reactive-form#insertEntity hw-combobox:selection->dynamic-description#updateDescription",
                      value: ".hw-combobox__input" }
          end

          div(class: "w-full lg:w-1/4 mb-2") do
            bold_label(form, :month_year)

            if budget.new_record?
              Combobox term: model_attribute(budget, :month_years) do
                ComboboxTrigger(placeholder: model_attribute(budget, :month_year))

                ComboboxPopover do
                  div(class: "my-1") do
                    ComboboxSearchInput(placeholder: action_message(:type))
                  end

                  ComboboxList do
                    ComboboxEmptyState { I18n.t(:rows_not_found) }

                    ComboboxItem(class: "mt-1") do
                      ComboboxToggleAllCheckbox(name: "all", value: action_message(:all))
                      span { action_message(:select_all) }
                    end

                    current_year = Date.today.year
                    next_year = current_year + 1
                    [ current_year, next_year ].each do |year|
                      ComboboxListGroup label: year do
                        (1..12).each do |month|
                          value = Date.new(year, month)
                          next if value < Time.zone.today

                          month = I18n.t("date.month_names")[month]

                          ComboboxItem do
                            ComboboxCheckbox(name: "month_years[]", value:)
                            span { month }
                          end
                        end
                      end
                    end
                  end
                end
              end
            else
              budget_date = budget.new_record? ? Time.zone.today : Date.new(budget.year, budget.month, 1)
              TextField \
                form, :month_year,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: budget_date.strftime("%Y-%m"),
                data: { dynamic_description_target: :monthYear, action: "input->dynamic-description#updateDescription" }
            end
          end

          div do
            bold_label(form, :value)

            div(class: "flex-1 flex gap-x-1 mb-3 lg:mb-0") do
              Button(size: :lg, class: "w-1/6 bg-red-500 border border-black hover:bg-red-600", tabindex: -1) { "-" }

              div(class: "w-full lg:w-5/6") do
                TextField \
                  form, :value,
                  inputmode: :numeric,
                  svg: :money,
                  class: "font-graduate",
                  value: budget.value || -10_000,
                  onclick: "this.select();",
                  data: { dynamic_description_target: :value,
                          price_mask_target: :input, action: "input->price-mask#applyMask input->dynamic-description#updateDescription",
                          sign: "-" }
              end
            end
          end
        end

        div(class: "flex items-center justify-center gap-2 w-1/2 mb-3 mx-auto") do
          div(class: "w-full lg:w-1/2 mb-2") do
            bold_label(form, :first_installment_only)
            div(class: "mb-3") do
              form.checkbox :first_installment_only, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: budget.first_installment_only
            end
          end

          div(class: "w-full lg:w-1/2 mb-2") do
            bold_label(form, :active)
            div(class: "mb-3") do
              form.checkbox :active, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: budget.new_record? || budget.active
            end
          end
        end

        div(id: "categories_nested", class: "flex gap-2 overflow-x-auto pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data_nested_form_target: "template") do
            form.fields_for :budget_categories, BudgetCategory.new, child_index: "NEW_RECORD" do |budget_category_fields|
              render CategoryFields.new(form: budget_category_fields)
            end
          end

          budget_categories_association = budget.budget_categories.includes(:category) if budget.budget_categories.count > 1
          form.fields_for :budget_categories, budget_categories_association do |budget_category_fields|
            render CategoryFields.new(form: budget_category_fields)
          end

          div(data_nested_form_target: "target")

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addCategory, action: "nested-form#add" })
        end

        div(id: "entities_nested", class: "flex gap-2 overflow-x-auto pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data_nested_form_target: "template") do
            form.fields_for :budget_entities, BudgetEntity.new, child_index: "NEW_RECORD" do |budget_entity_fields|
              render EntityFields.new(form: budget_entity_fields)
            end
          end

          budget_entities_association = budget.budget_entities.includes(:entity) if budget.budget_entities.count > 1
          form.fields_for :budget_entities, budget_entities_association do |budget_entity_fields|
            render EntityFields.new(form: budget_entity_fields)
          end

          div(data_nested_form_target: "target")

          button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
        end

        div(class: "grid grid-cols-1 lg:flex items-center justify-center gap-2 mx-auto") do
          Button(type: :submit, variant: :purple) { action_model(:submit, budget) }

          if budget.persisted?
            LinkWithConfirmation(
              id: budget.id,
              text: action_model(:destroy, budget),
              link_params: {
                href: v1_budget_path(budget),
                id: "delete_budget_#{budget.id}",
                variant: :destructive,
                data: { turbo_method: :delete }
              }
            )

            card_transactions_sheet
            cash_transactions_sheet
            exchange_return_cash_transactions_sheet
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  def categories_json
    current_user.categories.to_h do |c|
      [ c.id, c.hex_colour ]
    end.to_json
  end

  def entities_json
    current_user.entities.to_h do |c|
      [ c.id, asset_path("avatars/#{c.avatar_name}") ]
    end.to_json
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
            p { budget.categories.map(&:name).join(", ") }
            p { budget.entities.map(&:entity_name).join(", ") }
          end
        end

        SheetMiddle(class: "overflow-y-auto flex-1") do
          installment_number = budget.first_installment_only ? 1 : nil

          SheetMiddle do
            index_context = {
              current_user:,
              years: [ budget.year ],
              default_year: budget.year,
              active_month_years: [ Date.new(budget.year, budget.month).strftime("%Y%m").to_i ],
              search_term: "",
              category_id: budget.categories.pluck(:id),
              entity_id: budget.entities.pluck(:id),
              user_bank_account_id: nil,
              from_ct_price: nil,
              to_ct_price: nil,
              from_price: nil,
              to_price: nil,
              from_installments_count: nil,
              to_installments_count: nil,
              from_installments_number: installment_number,
              to_installments_countnumber: installment_number,
              user_card: nil,
              skip_budgets: true,
              force_mobile: true
            }

            render Views::V1::CardTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end

  def cash_transactions_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, class: "w-full") do
          action_model(:index, CashTransaction, 2)
        end
      end

      SheetContent(side: :middle, class: "w-full md:w-1/3 max-h-[90vh] flex flex-col") do
        SheetHeader do
          SheetTitle { pluralise_model(CashTransaction, 2) }
          SheetDescription do
            p { budget.categories.map(&:name).join(", ") }
            p { budget.entities.map(&:entity_name).join(", ") }
          end
        end

        SheetMiddle(class: "overflow-y-auto flex-1") do
          SheetMiddle do
            index_context = {
              current_user:,
              years: [ budget.year ],
              default_year: budget.year,
              active_month_years: [ Date.new(budget.year, budget.month).strftime("%Y%m").to_i ],
              search_term: "",
              category_id: budget.categories.map(&:id),
              entity_id: budget.entities.map(&:id),
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

            render Views::V1::CashTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end

  def exchange_return_cash_transactions_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, class: "w-full") do
          action_model(:index, Exchange, 2)
        end
      end

      SheetContent(side: :middle, class: "w-full md:w-1/3 max-h-[90vh] flex flex-col") do
        SheetHeader do
          SheetTitle { pluralise_model(Exchange, 2) }
          SheetDescription do
            p { budget.categories.map(&:name).join(", ") }
            p { budget.entities.map(&:entity_name).join(", ") }
          end
        end

        SheetMiddle(class: "overflow-y-auto flex-1") do
          SheetMiddle do
            index_context = {
              current_user:,
              years: [ budget.year ],
              default_year: budget.year,
              active_month_years: [ Date.new(budget.year, budget.month).strftime("%Y%m").to_i ],
              search_term: "",
              category_id: [],
              entity_id: [],
              user_bank_account_id: nil,
              from_ct_price: nil,
              to_ct_price: nil,
              from_price: nil,
              to_price: nil,
              from_installments_count: nil,
              to_installments_count: nil,
              user_card: nil,
              skip_budgets: true,
              include_exchange_return_from_category: true,
              force_mobile: true,
              cash_installment_ids: exchange_return_cash_installment_ids
            }

            render Views::V1::CashTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end

  def exchange_return_cash_installment_ids
    return [ 0 ] unless budget.persisted?

    relevant_card_trx_ids = current_user.card_transactions.joins(:category_transactions).where(category_transactions: { category_id: budget.categories.ids }).ids

    return [ 0 ] if relevant_card_trx_ids.empty?

    exchange_return_cash_installments =
      current_user.cash_installments
                  .where(year: budget.year, month: budget.month)
                  .joins(cash_transaction: { exchanges: :entity_transaction })
                  .where(entity_transactions: { transactable_type: "CardTransaction", transactable_id: relevant_card_trx_ids })
                  .ids

    return [ 0 ] if exchange_return_cash_installments.empty?

    exchange_return_cash_installments
  end
end
