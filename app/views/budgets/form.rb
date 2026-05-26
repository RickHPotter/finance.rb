# frozen_string_literal: true

class Views::Budgets::Form < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Views::Budgets

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
        id: "form",
        class: "contents text-black",
        data: { controller: "reactive-form price-mask dynamic-description", reactive_form_quick_jump_value: true, action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        hidden_field_tag :category_colours, categories_json, disabled: true, data: { reactive_form_target: :categoryColours }
        hidden_field_tag :entity_icons,     entities_json,   disabled: true, data: { reactive_form_target: :entityIcons }

        div(class: "w-full mb-6") do
          form.text_field \
            :description,
            autocomplete: :off,
            autofocus: true,
            class: outdoor_readonly_input_class,
            data: { controller: "blinking-placeholder", text: model_attribute(budget, :description), dynamic_description_target: :description }
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "budget_category_combobox", class: "combobox-shell w-full lg:w-1/4 mb-3 plus-icon", data: { reactive_form_target: :categoryCombobox }) do
            bold_label(form, :categories)
            render Views::Shared::SingleSelectCombobox.new(
              name: :budget_category,
              options: @categories.map { |label, value| [ label, value, {} ] },
              selected_value: nil,
              placeholder: model_attribute(budget, :category_id),
              input_data: {
                action: "change->reactive-form#insertCategory change->dynamic-description#updateDescription"
              }
            )
          end

          div(id: "budget_entity_combobox", class: "combobox-shell w-full lg:w-1/4 mb-3 user-icon", data: { reactive_form_target: :entityCombobox }) do
            bold_label(form, :entities)
            render Views::Shared::SingleSelectCombobox.new(
              name: :budget_entity,
              options: @entities.map { |label, value| [ label, value, {} ] },
              selected_value: nil,
              placeholder: model_attribute(budget, :entity_id),
              input_data: {
                action: "change->reactive-form#insertEntity change->dynamic-description#updateDescription"
              }
            )
          end

          div(class: "w-full lg:w-1/4 mb-2") do
            bold_label(form, :month_year)

            if budget.new_record?
              div(data: { reactive_form_target: :monthYearCombobox }) do
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
              end
            else
              budget_date = budget.new_record? ? Time.zone.today : Date.new(budget.year, budget.month, 1)
              TextField \
                form, :month_year,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: budget_date.strftime("%Y-%m"),
                data: { reactive_form_target: :monthYearInput, dynamic_description_target: :monthYear, action: "input->dynamic-description#updateDescription" }
            end
          end

          div(class: "w-full lg:w-1/4") do
            positive = budget.value.to_i.positive?
            sign_bg_colour = positive ? "bg-green-300" : "bg-red-300"
            sign = positive ? "+" : "-"

            bold_label(form, :value)

            div(class: "flex-1 flex gap-x-1 mb-3 lg:mb-0") do
              Button(
                type: :button,
                size: :lg,
                class: "w-1/6 #{sign_bg_colour} border border-black lg:hidden",
                tabindex: -1,
                title: action_message(:toggle_sign),
                data: { action: "click->price-mask#toggleSign", target: ".sign-based" }
              ) { sign }

              div(class: "w-5/6 lg:w-full") do
                TextField \
                  form, :value,
                  inputmode: :numeric,
                  svg: :money,
                  class: "sign-based font-graduate",
                  value: budget.value || -10_000,
                  data: { controller: "input-select",
                          dynamic_description_target: :value,
                          reactive_form_target: :priceInput,
                          price_mask_target: :input, action: "click->input-select#select input->price-mask#applyMask input->dynamic-description#updateDescription",
                          sign: }
              end
            end
          end
        end

        div(class: "mb-3 grid grid-cols-1 gap-2 mx-auto sm:grid-cols-3") do
          div(class: "w-full mb-2") do
            bold_label(form, :inclusive)
            div(class: "mb-3") do
              form.checkbox :inclusive,
                            class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500",
                            checked: budget.inclusive,
                            data: { dynamic_description_target: :inclusive, action: "change->dynamic-description#updateDescription" }
            end
          end

          div(class: "w-full mb-2") do
            bold_label(form, :first_installment_only)
            div(class: "mb-3") do
              form.checkbox :first_installment_only,
                            class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500",
                            checked: budget.first_installment_only
            end
          end

          div(class: "w-full mb-2") do
            bold_label(form, :active)
            div(class: "mb-3") do
              form.checkbox :active,
                            class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500",
                            checked: budget.new_record? || budget.active
            end
          end
        end

        div(class: "mb-3 grid grid-cols-1 gap-3 items-stretch md:grid-cols-2 md:gap-0") do
          render Views::Budgets::FormCategoriesSection.new(form:, budget:)
          render Views::Budgets::FormEntitiesSection.new(form:, budget:)
        end

        render_actions_row

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  def categories_json
    current_user.categories.to_h do |c|
      [ c.id, c.hex_colour ]
    end.to_json
  end

  def render_actions_row
    if budget.persisted?
      persisted_actions_row
    else
      new_record_actions_row
    end
  end

  def persisted_actions_row
    div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
      Button(type: :submit, class: "min-w-64 #{submit_button_class(form_action_mode(budget))}") { action_message(:submit) }

      Button(
        link: duplicate_budget_path(budget),
        class: "min-w-64 #{duplicate_button_class}",
        data: { turbo_frame: "_top" }
      ) do
        action_message(:duplicate)
      end

      LinkWithConfirmation(
        id: budget.id,
        text: action_message(:destroy),
        link_params: {
          href: budget_path(budget),
          id: "delete_budget_#{budget.id}",
          variant: :outline,
          class: "min-w-64 #{destroy_button_class}",
          data: { turbo_method: :delete }
        }
      )

      list_menu
    end
  end

  def new_record_actions_row
    div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
      Button(type: :submit, class: "min-w-64 #{submit_button_class(form_action_mode(budget))}") { action_message(:submit) }
    end
  end

  def entities_json
    current_user.entities.to_h do |c|
      [ c.id, asset_path("avatars/#{c.avatar_name}") ]
    end.to_json
  end

  def card_transactions_sheet
    card_transactions_sheet_with_trigger("w-full", action_model(:index, CardTransaction, 2))
  end

  def card_transactions_sheet_with_trigger(trigger_class, label)
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: trigger_class) do
          label
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
              to_installments_number: installment_number,
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

  def cash_transactions_sheet
    cash_transactions_sheet_with_trigger("w-full", action_model(:index, CashTransaction, 2))
  end

  def cash_transactions_sheet_with_trigger(trigger_class, label)
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: trigger_class) do
          label
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
              from_installments_number: budget.first_installment_only ? 1 : nil,
              to_installments_number: budget.first_installment_only ? 1 : nil,
              user_card: nil,
              skip_budgets: true,
              force_mobile: true
            }

            render Views::CashTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end

  def exchange_return_cash_transactions_sheet
    exchange_return_cash_transactions_sheet_with_trigger("w-full", action_model(:index, Exchange, 2))
  end

  def exchange_return_cash_transactions_sheet_with_trigger(trigger_class, label)
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: trigger_class) do
          label
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

            render Views::CashTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end

  def exchange_return_cash_installment_ids
    return [ 0 ] unless budget.persisted?

    relevant_card_trx_ids =
      current_context.card_transactions
                     .joins(:category_transactions)
                     .where(category_transactions: { category_id: budget.categories.ids })
                     .ids

    return [ 0 ] if relevant_card_trx_ids.empty?

    exchange_return_cash_installments =
      current_context.cash_installments
                     .where(year: budget.year, month: budget.month)
                     .joins(cash_transaction: { exchanges: :entity_transaction })
                     .where(entity_transactions: { transactable_type: "CardTransaction", transactable_id: relevant_card_trx_ids })
                     .ids

    return [ 0 ] if exchange_return_cash_installments.empty?

    exchange_return_cash_installments
  end

  def list_menu
    Popover(options: { trigger: "click", placement: "bottom-start" }, class: "relative z-50 shrink-0") do
      PopoverTrigger(class: "flex") do
        Button(type: :button, class: "min-w-64") { "List" }
      end

      PopoverContent(class: "z-60 opacity-100! min-w-64 p-1") do
        div(class: "flex flex-col gap-1") do
          card_transactions_sheet_with_trigger(sheet_menu_item_button_class, action_model(:index, CardTransaction, 2))
          cash_transactions_sheet_with_trigger(sheet_menu_item_button_class, action_model(:index, CashTransaction, 2))
          exchange_return_cash_transactions_sheet_with_trigger(sheet_menu_item_button_class, action_model(:index, Exchange, 2))
        end
      end
    end
  end

  def sheet_menu_item_button_class
    "w-full justify-start rounded-md px-3 py-2 text-left text-sm font-semibold text-slate-700 hover:bg-slate-100"
  end
end
