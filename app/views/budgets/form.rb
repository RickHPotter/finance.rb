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
        data: {
          controller: "reactive-form price-mask dynamic-description budget-value-helper",
          reactive_form_quick_jump_value: true,
          budget_value_helper_consumed_value: consumed_value_for_helper,
          action: "submit->price-mask#removeMasks"
        }
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

        div(class: "grid grid-cols-1 gap-2 w-full mb-3 lg:grid-cols-12") do
          div(id: "budget_category_combobox", class: "combobox-shell w-full lg:col-span-3 mb-3 plus-icon", data: { reactive_form_target: :categoryCombobox }) do
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

          div(id: "budget_entity_combobox", class: "combobox-shell w-full lg:col-span-3 mb-3 user-icon", data: { reactive_form_target: :entityCombobox }) do
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

          div(class: "w-full lg:col-span-2 mb-2") do
            bold_label(form, :month_year)

            if budget.new_record?
              div(data: { reactive_form_target: :monthYearCombobox }) do
                Combobox term: model_attribute(budget, :month_years) do
                  ComboboxTrigger(
                    placeholder: model_attribute(budget, :month_year),
                    class: ref_month_year_trigger_class
                  )

                  ComboboxPopover(class: ref_month_year_popover_class) do
                    div(class: "my-1") do
                      ComboboxSearchInput(placeholder: action_message(:type), class: ref_month_year_search_class)
                    end

                    ComboboxList(class: "flex max-h-72 flex-col gap-1 overflow-y-auto p-1 text-foreground dark:text-slate-100") do
                      ComboboxEmptyState { I18n.t(:rows_not_found) }

                      ComboboxItem(class: "mt-1 dark:text-slate-100 dark:hover:bg-slate-800") do
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

                            ComboboxItem(class: "dark:text-slate-100 dark:hover:bg-slate-800") do
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

          div(class: "w-full lg:col-span-4") do
            positive = budget.value.to_i.positive?
            sign_bg_colour = positive ? "bg-green-300" : "bg-red-300"
            sign = positive ? "+" : "-"

            div(class: "flex-1 grid grid-cols-12 gap-x-1 mb-3 lg:mb-0") do
              Button(
                type: :button,
                size: :lg,
                class: "col-span-2 self-end #{sign_bg_colour} border border-black lg:hidden",
                tabindex: -1,
                title: action_message(:toggle_sign),
                data: { action: "click->price-mask#toggleSign", target: ".sign-based" }
              ) { sign }

              div(class: "col-span-10 lg:col-span-5") do
                bold_label(form, :value)

                TextField \
                  form, :value,
                  inputmode: :numeric,
                  svg: :money,
                  class: "sign-based font-graduate",
                  value: budget.value || -10_000,
                  data: { controller: "input-select",
                          dynamic_description_target: :value,
                          reactive_form_target: :priceInput,
                          budget_value_helper_target: :value,
                          price_mask_target: :input,
                          action: [
                            "click->input-select#select",
                            "input->price-mask#applyMask",
                            "input->dynamic-description#updateDescription",
                            "input->budget-value-helper#updateRemaining"
                          ].join(" "),
                          sign: }
              end

              render_value_adjustment_modal

              div(class: "col-span-12 lg:col-span-5 mt-1 lg:mt-0") do
                div(class: "truncate") { bold_label(form, :remaining_value) }

                TextField \
                  form, :remaining_value,
                  inputmode: :numeric,
                  svg: :money,
                  class: "font-graduate bg-slate-100 text-slate-700",
                  value: budget.remaining_value || budget.value || -10_000,
                  disabled: true,
                  data: { budget_value_helper_target: :remaining, price_mask_target: :input }
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

  def render_value_adjustment_modal
    modal_id = "budget_value_adjustment_modal"

    div(class: "col-span-12 lg:col-span-2 mt-1 lg:mt-0 self-end") do
      span(class: "invisible font-poetsen-one text-medium font-bold text-gray-500") { "" }

      Button(
        type: :button,
        size: :lg,
        class: calc_button_class,
        data: { modal_target: modal_id, modal_toggle: modal_id }
      ) do
        cached_icon(:calculator)
      end
    end

    ModalShell(
      id: modal_id,
      title: model_attribute(budget, :value),
      options: { content_class: "w-[calc(100vw-2rem)] max-w-md text-black dark:text-slate-100" }
    ) do
      div(class: "space-y-4", data: { budget_value_helper_target: :modal }) do
        div(class: "flex gap-1") do
          Button(
            type: :button,
            size: :lg,
            class: "w-14 bg-green-300 border border-black text-black dark:border-green-500 dark:bg-green-700/80 dark:text-white sm:hidden",
            data: { budget_value_helper_target: :signToggle, action: "click->budget-value-helper#toggleAdjustmentSign" }
          ) { "+" }

          div(class: "relative w-full") do
            div(class: "absolute inset-y-0 inset-s-0 flex items-center ps-3.5 pointer-events-none z-1") do
              cached_icon(:money)
            end

            input(
              type: :text,
              inputmode: :numeric,
              class: "#{input_class} dynamic-price font-graduate",
              value: 0,
              data: {
                budget_value_helper_target: :adjustment,
                price_mask_target: :input,
                action: "click->input-select#select input->price-mask#applyMask input->budget-value-helper#clampAdjustment",
                sign: "+"
              }
            )
          end
        end

        div(class: "grid grid-cols-4 gap-2") do
          [ -500, -1_000, -5_000, -10_000 ].each do |amount|
            button(
              type: :button,
              class: adjustment_shortcut_button_class,
              data: {
                action: "click->budget-value-helper#incrementAdjustment",
                budget_value_helper_adjustment_param: amount
              }
            ) do
              "-#{amount.abs / 100}"
            end
          end
        end

        div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
          button(
            type: :button,
            class: modal_confirm_button_class(:green),
            data: { action: "click->budget-value-helper#applyAdjustment", modal_hide: modal_id }
          ) do
            I18n.t("confirmation.confirm")
          end

          button(
            type: :button,
            class: modal_cancel_button_class,
            data: { modal_hide: modal_id }
          ) do
            I18n.t("confirmation.cancel")
          end
        end
      end
    end
  end

  def consumed_value_for_helper
    return 0 unless budget.persisted?

    budget.value.to_i - budget.remaining_value.to_i
  end

  def ref_month_year_trigger_class
    "flex h-10 w-full items-center justify-between overflow-hidden whitespace-nowrap rounded-md border border-slate-300 bg-white px-4 py-2 " \
      "text-sm text-slate-900 shadow-sm transition-colors hover:border-slate-400 hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-ring " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700/70 dark:focus-visible:ring-sky-500/60"
  end

  def ref_month_year_popover_class
    "absolute inset-auto m-0 rounded-lg border bg-background shadow-lg dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
  end

  def ref_month_year_search_class
    "flex h-10 w-full rounded-md border-none bg-transparent py-3 text-sm outline-none placeholder:text-muted-foreground " \
      "dark:text-slate-100 dark:placeholder:text-slate-500"
  end

  def calc_button_class
    "h-10 w-full min-w-12 border border-black bg-white px-2 text-black hover:bg-slate-100 dark:border-slate-700 dark:bg-slate-900 " \
      "dark:text-slate-200 dark:hover:bg-slate-800"
  end

  def adjustment_shortcut_button_class
    "rounded border border-slate-300 bg-slate-100 px-2 py-2 text-sm font-bold text-slate-900 hover:bg-slate-200 " \
      "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
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

  def card_transactions_sheet_with_trigger(trigger_class, label, count: nil)
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: budget_sheet_trigger_button_class(trigger_class)) do
          sheet_trigger_label(label, count)
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

  def cash_transactions_sheet_with_trigger(trigger_class, label, count: nil)
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: budget_sheet_trigger_button_class(trigger_class)) do
          sheet_trigger_label(label, count)
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

  def exchange_return_cash_transactions_sheet_with_trigger(trigger_class, label, count: nil)
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: budget_sheet_trigger_button_class(trigger_class)) do
          sheet_trigger_label(label, count)
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
    Popover(options: { trigger: "click", placement: "bottom-start" }, class: "relative z-40 shrink-0") do
      PopoverTrigger(class: "flex") do
        Button(type: :button, class: submit_row_ghost_button_class) { action_message(:index) }
      end

      PopoverContent(class: "z-40 opacity-100! min-w-64 p-1") do
        div(class: "flex flex-col gap-1") do
          card_transactions_sheet_with_trigger(
            sheet_menu_item_button_class,
            pluralise_model(CardTransaction, 2),
            count: card_transactions_sheet_count
          )
          cash_transactions_sheet_with_trigger(
            sheet_menu_item_button_class,
            pluralise_model(CashTransaction, 2),
            count: cash_transactions_sheet_count
          )
          exchange_return_cash_transactions_sheet_with_trigger(
            sheet_menu_item_button_class,
            pluralise_model(Exchange, 2),
            count: exchange_return_cash_transactions_sheet_count
          )
        end
      end
    end
  end

  def sheet_trigger_label(label, count)
    return label if count.nil?

    div(class: "flex w-full items-center justify-between gap-3") do
      span { label }
      span(class: "rounded-full bg-slate-200 px-2 py-0.5 text-xs font-bold text-slate-700") { count }
    end
  end

  def card_transactions_sheet_count
    @card_transactions_sheet_count ||= Logic::CardInstallments.find_ref_month_year_by_params(
      current_context,
      budget_sheet_transaction_params,
      budget_sheet_search_params
    ).reorder(nil).distinct.count(:card_transaction_id)
  end

  def cash_transactions_sheet_count
    @cash_transactions_sheet_count ||= begin
      cash_installments, = Logic::CashTransactions.find_by_ref_month_year(
        current_context,
        budget_sheet_transaction_params,
        budget_sheet_search_params.merge(skip_budgets: true)
      )
      cash_installments.reorder(nil).distinct.count(:cash_transaction_id)
    end
  end

  def exchange_return_cash_transactions_sheet_count
    @exchange_return_cash_transactions_sheet_count ||= current_context.cash_installments
                                                                      .where(id: exchange_return_cash_installment_ids)
                                                                      .distinct
                                                                      .count(:cash_transaction_id)
  end

  def budget_sheet_transaction_params
    {
      category_id: budget.categories.ids,
      entity_id: budget.entities.ids
    }
  end

  def budget_sheet_search_params
    installment_number = budget.first_installment_only ? 1 : nil

    {
      month_year: Date.new(budget.year, budget.month).strftime("%Y%m"),
      search_term: "",
      from_installments_number: installment_number,
      to_installments_number: installment_number
    }
  end

  def sheet_menu_item_button_class
    "w-full justify-start rounded-md px-3 py-2 text-left text-sm font-semibold text-slate-700 hover:bg-slate-100"
  end

  def submit_row_ghost_button_class
    secondary_submit_row_button_class("min-w-64")
  end

  def budget_sheet_trigger_button_class(trigger_class)
    "#{trigger_class} dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
