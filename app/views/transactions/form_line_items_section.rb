# frozen_string_literal: true

class Views::Transactions::FormLineItemsSection < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FieldsFor
  include TranslateHelper
  include CacheHelper
  include ComponentsHelper

  attr_reader :form, :transaction, :categories, :entities

  def initialize(form:, transaction:, categories:, entities:)
    @form = form
    @transaction = transaction
    @categories = categories
    @entities = entities
  end

  def view_template
    div(class: "mb-0") do
      expanded_section
    end
  end

  private

  def expanded_section
    Sheet(data: { controller: "composite-entity-modal" }) do
      div(
        class: "overflow-hidden rounded-lg border border-gray-300 bg-white dark:border-slate-700/60 dark:bg-slate-900/30",
        data: { composite_transaction_target: "container" }
      ) do
        summary_strip
        bulk_allocation_controls

        div(class: "divide-y divide-gray-200 dark:divide-slate-700/40",
            data: { composite_transaction_target: "itemsList" }) do
          render_existing_rows
        end

        render_template
      end

      render Views::Transactions::FormLineItemEntityModal.new(form:, transaction:)
    end
  end

  def summary_strip
    div(class: "flex flex-wrap items-center gap-x-4 gap-y-1 border-b border-gray-200 bg-gray-50 px-3 py-1.5 text-xs dark:border-slate-700/40 dark:bg-slate-800/30") do
      div(class: "flex items-center gap-1.5") do
        span(class: "text-gray-500 dark:text-slate-500") { I18n.t("transactions.composite.parent_total") }
        span(class: "font-semibold text-gray-800 font-graduate dark:text-slate-200 dark:font-mono",
             data: { composite_transaction_target: "parentTotal" }) { "R$ 0,00" }
      end
      div(class: "text-gray-300 dark:text-slate-600") { "|" }
      div(class: "flex items-center gap-1.5") do
        span(class: "text-gray-500 dark:text-slate-500") { I18n.t("transactions.composite.allocated_sum") }
        span(class: "font-semibold text-gray-800 font-graduate dark:text-slate-200 dark:font-mono",
             data: { composite_transaction_target: "allocatedSum" }) { "R$ 0,00" }
      end
      div(class: "text-gray-300 dark:text-slate-600") { "|" }
      div(class: "flex items-center gap-1.5") do
        span(class: "text-gray-500 dark:text-slate-500",
             data: { composite_transaction_target: "differenceLabel" }) { I18n.t("transactions.composite.remaining") }
        span(
          class: "font-semibold text-gray-800 font-graduate dark:text-slate-200 dark:font-mono",
          data: {
            composite_transaction_target: "differenceBadge",
            balanced_text: I18n.t("transactions.composite.balanced"),
            min_items_text: I18n.t("transactions.composite.min_items_needed"),
            remaining_text: I18n.t("transactions.composite.remaining"),
            over_allocated_text: I18n.t("transactions.composite.over_allocated")
          }
        ) { "R$ 0,00" }
      end
      div(class: "ml-auto") do
        Button(
          type: :button,
          variant: :ghost,
          size: :sm,
          class: "gap-1 text-xs text-gray-500 hover:text-gray-900 hover:bg-gray-100 px-2 py-1 h-auto " \
                 "dark:text-slate-400 dark:hover:text-slate-100 dark:hover:bg-slate-800 cursor-pointer",
          data: { action: "click->composite-transaction#addRow" }
        ) do
          cached_icon(:plus)
          span { I18n.t("transactions.composite.add_item") }
        end
      end
    end
  end

  def render_existing_rows
    items = transaction.line_items.to_a
    return render_initial_row if items.empty?

    items.each_with_index do |item, idx|
      form.fields_for :line_items, item, child_index: idx do |item_form|
        render_row(item_form, item, idx)
      end
    end
  end

  def bulk_allocation_controls
    div(class: "grid grid-cols-1 gap-2 border-b border-gray-200 bg-white p-3 dark:border-slate-700/40 dark:bg-slate-900/30 sm:grid-cols-[1fr_1fr_auto]") do
      div(class: "text-xs font-medium text-slate-600 dark:text-slate-300 sm:col-span-3") do
        I18n.t("transactions.composite.bulk_defaults")
      end

      render Views::Shared::SingleSelectCombobox.new(
        name: "line_item_bulk_category_id",
        options: categories,
        selected_value: nil,
        placeholder: I18n.t("activerecord.attributes.line_item.category_id"),
        size: :sm,
        combobox_data: { composite_transaction_target: "bulkCategory" }
      )
      render Views::Shared::SingleSelectCombobox.new(
        name: "line_item_bulk_entity_id",
        options: entities.map { |label, value| [ label, value, {} ] },
        selected_value: nil,
        placeholder: I18n.t("activerecord.attributes.line_item.entity_id"),
        size: :sm,
        combobox_data: { composite_transaction_target: "bulkEntity" }
      )
      Button(
        type: :button,
        variant: :outline,
        size: :sm,
        class: "whitespace-nowrap",
        data: { action: "click->composite-transaction#applyBulkAllocations" }
      ) { I18n.t("transactions.composite.apply_to_all") }

      p(
        class: "hidden text-xs text-emerald-700 dark:text-emerald-300 sm:col-span-3",
        role: :status,
        data: { composite_transaction_target: "bulkAllocationStatus", applied_text: I18n.t("transactions.composite.defaults_applied") }
      )
    end
  end

  def render_initial_row
    item = LineItem.new
    form.fields_for :line_items, item, child_index: 0 do |item_form|
      render_row(item_form, item, 0)
    end
  end

  def render_template
    template(data: { composite_transaction_target: "template" }) do
      form.fields_for :line_items, LineItem.new, child_index: "NEW_LINE_ITEM" do |item_form|
        render_row(item_form, LineItem.new, "NEW_LINE_ITEM")
      end
    end
  end

  def render_row(item_form, item, index)
    div(
      class: row_class(item),
      data: {
        composite_transaction_target: "row",
        persisted: item.persisted?.to_s
      }
    ) do
      item_form.hidden_field :id if item.persisted?
      item_form.hidden_field :_destroy, value: (item.marked_for_destruction? ? "1" : "0")

      div(class: "grid min-w-0 flex-1 grid-cols-1 items-center gap-2 #{row_grid_class}") do
        div(class: "min-w-0") do
          item_form.text_field(
            :description,
            placeholder: I18n.t("activerecord.attributes.line_item.description"),
            class: "#{input_class_without_icon} h-9 px-2.5 py-1.5 text-xs",
            autocomplete: "off"
          )
        end

        div(class: "min-w-0") do
          item_form.text_field(
            :price,
            value: (item.price.present? && item.price != 0 ? item.price : nil),
            placeholder: I18n.t("activerecord.attributes.line_item.price"),
            inputmode: :numeric,
            class: "#{input_class_without_icon} h-9 px-2.5 py-1.5 text-xs font-graduate dark:font-mono sign-based",
            autocomplete: "off",
            data: {
              price_mask_target: "input",
              composite_transaction_target: "itemPrice",
              action: "input->price-mask#applyMask input->composite-transaction#recalculate input->composite-entity-modal#priceChanged",
              sign: price_sign
            }
          )
        end

        line_item_exchange_intent(item, index) if transaction.is_a?(CashTransaction)

        div(class: "combobox-shell min-w-0 plus-icon") do
          render Views::Shared::SingleSelectCombobox.new(
            name: "#{form.object_name}[line_items_attributes][#{index}][category_id]",
            options: categories,
            selected_value: item.category_id,
            placeholder: I18n.t("activerecord.attributes.line_item.category_id"),
            input_data: {
              action: "change->composite-transaction#recalculate change->reactive-form#syncExchangeIntentVisibility"
            }
          )
        end

        div(class: "flex min-w-0") do
          div(class: "combobox-shell user-icon min-w-0 flex-1") do
            render Views::Shared::SingleSelectCombobox.new(
              name: "#{form.object_name}[line_items_attributes][#{index}][entity_transactions_attributes][0][entity_id]",
              options: entities.map { |label, value| [ label, value, {} ] },
              selected_value: item.entity_id,
              placeholder: I18n.t("activerecord.attributes.line_item.entity_id"),
              input_data: { action: "change->composite-entity-modal#entityChanged" },
              trigger_class: "rounded-r-none",
              trigger_data: { composite_entity_modal_target: "entityPicker" }
            )
          end

          SheetTrigger(
            class: "shrink-0",
            data: {
              composite_entity_modal_target: "trigger",
              line_item_key: index.to_s,
              action: "click->composite-entity-modal#open"
            }
          ) do
            button(
              type: :button,
              disabled: item.entity_id.blank?,
              class: "flex h-10 items-center gap-1 whitespace-nowrap rounded-l-none rounded-r-md border border-l-0 border-slate-300 px-2 " \
                     "text-xs text-slate-700 hover:bg-slate-100 disabled:opacity-40 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
            ) do
              cached_icon(:user_group)
              span { I18n.t("transactions.composite.entity_modal_trigger") }
            end
          end
        end
      end

      Button(
        type: :button,
        variant: :ghost,
        size: :icon,
        class: "shrink-0 h-8 w-8 text-gray-400 hover:text-red-500 hover:bg-red-50 dark:text-slate-500 dark:hover:text-red-400 dark:hover:bg-red-500/10",
        data: { action: "click->composite-transaction#removeRow" }
      ) do
        cached_icon(:destroy)
      end
    end
  end

  def line_item_exchange_intent(item, index)
    disabled = !line_item_payer?(item)
    name = "#{form.object_name}[line_items_attributes][#{index}][friend_notification_intent]"
    option_class = "bg-white text-slate-900 dark:bg-slate-800 dark:text-slate-100"

    div(class: "min-w-0", data: { line_item_exchange_intent: true }) do
      select(
        name:,
        id: "line_item_friend_notification_intent_#{index}",
        aria: { label: I18n.t("activerecord.attributes.cash_transaction.friend_notification_intent") },
        disabled:,
        class: "h-9 w-full min-w-0 rounded-md border border-slate-300 bg-white px-2 text-xs text-slate-900 " \
               "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 " \
               "disabled:cursor-not-allowed disabled:border-slate-200 disabled:bg-slate-100 " \
               "disabled:text-slate-500 disabled:opacity-60 dark:disabled:border-slate-700 " \
               "dark:disabled:bg-slate-800/60 dark:disabled:text-slate-500",
        data: { line_item_exchange_intent: "input" }
      ) do
        option(value: "", selected: item.friend_notification_intent.blank?, class: option_class) do
          I18n.t("activerecord.attributes.cash_transaction.friend_notification_intent")
        end
        option(value: "loan", selected: item.friend_notification_intent == "loan", class: option_class) do
          I18n.t("activerecord.attributes.cash_transaction.friend_notification_intents.loan")
        end
        option(value: "reimbursement", selected: item.friend_notification_intent == "reimbursement", class: option_class) do
          I18n.t("activerecord.attributes.cash_transaction.friend_notification_intents.reimbursement")
        end
      end
      input(
        type: :hidden,
        name:,
        value: "",
        disabled: !disabled,
        data: { line_item_exchange_intent: "hidden" }
      )
    end
  end

  def row_grid_class
    if transaction.is_a?(CashTransaction)
      "md:grid-cols-[3fr_2fr_2fr_4fr_5fr]"
    else
      "md:grid-cols-[3fr_2fr_4fr_5fr]"
    end
  end

  def line_item_payer?(item)
    item.entity_transactions.reject(&:marked_for_destruction?).any? do |entity_transaction|
      entity_transaction.is_payer? || entity_transaction_return_amount(entity_transaction).nonzero?
    end
  end

  def entity_transaction_return_amount(entity_transaction)
    amount = entity_transaction.price_to_be_returned.to_i
    return amount if amount.nonzero?

    active_exchanges = entity_transaction.exchanges.reject(&:marked_for_destruction?)
    return amount if active_exchanges.empty?

    active_exchanges.sum { |exchange| exchange.price.to_i }
  end

  def row_class(item)
    "flex items-center gap-2 px-3 py-2 #{'hidden' if item.marked_for_destruction?}"
  end

  def price_sign
    return "-" if transaction.is_a?(CardTransaction)

    transaction.price.to_i.negative? ? "-" : "+"
  end
end
