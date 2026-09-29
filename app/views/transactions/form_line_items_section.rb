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
    div(class: "mb-3") do
      toggle_row
      expanded_section
    end
  end

  private

  def toggle_row
    div(class: "flex items-center justify-between rounded-lg border border-slate-700/50 bg-slate-900/30 px-3 py-2") do
      div(class: "flex items-center gap-2") do
        span(class: "text-slate-400 shrink-0") { cached_icon(:category) }
        span(class: "text-sm font-semibold text-slate-200") { I18n.t("transactions.composite.split_purchase") }
        span(class: "text-xs text-slate-500") { "— #{I18n.t('transactions.composite.split_purchase_hint')}" }
      end
      Switch(
        name: "#{form.object_name}[split_purchase]",
        checked: transaction.composite?,
        data: {
          composite_transaction_target: "splitToggle",
          action: "change->composite-transaction#toggleSplit"
        }
      )
    end
  end

  def expanded_section
    div(
      class: "mt-1 #{'hidden' unless transaction.composite?}",
      data: { composite_transaction_target: "container" }
    ) do
      div(class: "rounded-lg border border-slate-700/50 bg-slate-900/20") do
        summary_strip

        div(class: "divide-y divide-slate-700/40", data: { composite_transaction_target: "itemsList" }) do
          render_existing_rows
        end

        render_template

        div(class: "px-3 py-2 border-t border-slate-700/40") do
          Button(
            type: :button,
            variant: :ghost,
            size: :sm,
            class: "gap-1.5 text-xs text-slate-400 hover:text-slate-200 hover:bg-slate-800/60 px-2",
            data: { action: "click->composite-transaction#addRow" }
          ) do
            cached_icon(:plus)
            span { I18n.t("transactions.composite.add_item") }
          end
        end
      end
    end
  end

  def summary_strip
    div(class: "flex flex-wrap items-center gap-x-4 gap-y-1 border-b border-slate-700/40 bg-slate-800/30 px-3 py-1.5 text-xs rounded-t-lg") do
      div(class: "flex items-center gap-1.5") do
        span(class: "text-slate-500") { I18n.t("transactions.composite.parent_total") }
        span(class: "font-semibold text-slate-200 font-graduate dark:font-mono",
             data: { composite_transaction_target: "parentTotal" }) { "R$ 0,00" }
      end
      div(class: "text-slate-600") { "|" }
      div(class: "flex items-center gap-1.5") do
        span(class: "text-slate-500") { I18n.t("transactions.composite.allocated_sum") }
        span(class: "font-semibold text-slate-200 font-graduate dark:font-mono",
             data: { composite_transaction_target: "allocatedSum" }) { "R$ 0,00" }
      end
      div(class: "ml-auto") do
        span(
          class: "inline-flex items-center rounded-full px-2 py-0.5 text-2xs font-semibold",
          data: {
            composite_transaction_target: "differenceBadge",
            balanced_text: I18n.t("transactions.composite.balanced"),
            min_items_text: I18n.t("transactions.composite.min_items_needed"),
            remaining_text: I18n.t("transactions.composite.remaining"),
            over_allocated_text: I18n.t("transactions.composite.over_allocated")
          }
        ) { I18n.t("transactions.composite.balanced") }
      end
    end
  end

  def render_existing_rows
    items = transaction.line_items.to_a
    items.each_with_index do |item, idx|
      form.fields_for :line_items, item, child_index: idx do |item_form|
        render_row(item_form, item, idx)
      end
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

      div(class: "min-w-0 flex flex-col md:flex-row items-center gap-2 flex-1") do
        div(class: "w-full md:w-4/12") do
          item_form.text_field(
            :description,
            placeholder: I18n.t("activerecord.attributes.line_item.description"),
            class: "#{input_class_without_icon} h-9 px-2.5 py-1.5 text-xs",
            autocomplete: "off"
          )
        end

        div(class: "w-full md:w-2/12") do
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
              action: "input->price-mask#applyMask input->composite-transaction#recalculate",
              sign: price_sign
            }
          )
        end

        div(class: "combobox-shell w-full md:w-3/12 plus-icon") do
          render Views::Shared::SingleSelectCombobox.new(
            name: "#{form.object_name}[line_items_attributes][#{index}][category_id]",
            options: categories,
            selected_value: item.category_id,
            placeholder: I18n.t("activerecord.attributes.line_item.category_id"),
            input_data: {
              action: "change->composite-transaction#recalculate"
            }
          )
        end

        div(class: "combobox-shell w-full md:w-3/12 user-icon") do
          render Views::Shared::SingleSelectCombobox.new(
            name: "#{form.object_name}[line_items_attributes][#{index}][entity_id]",
            options: entities.map { |label, value| [ label, value, {} ] },
            selected_value: item.entity_id,
            placeholder: I18n.t("activerecord.attributes.line_item.entity_id"),
            include_blank: true,
            blank_label: I18n.t("transactions.composite.no_entity")
          )
        end
      end

      Button(
        type: :button,
        variant: :ghost,
        size: :icon,
        class: "shrink-0 h-8 w-8 text-slate-500 hover:text-red-400 hover:bg-red-500/10",
        data: { action: "click->composite-transaction#removeRow" }
      ) do
        cached_icon(:destroy)
      end
    end
  end

  def row_class(item)
    "flex items-center gap-2 px-3 py-2 #{'hidden' if item.marked_for_destruction?}"
  end

  def price_sign
    return "-" if transaction.is_a?(CardTransaction)

    transaction.price.to_i.negative? ? "-" : "+"
  end
end
