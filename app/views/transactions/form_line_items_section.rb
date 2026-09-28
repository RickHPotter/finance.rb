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
    div(class: "mb-3 rounded-lg border border-slate-700/60 bg-slate-900/40 p-3") do
      div(class: "flex items-center justify-between") do
        div(class: "flex items-center gap-2") do
          div(class: "text-slate-400") { cached_icon(:category) }
          div do
            span(class: "text-sm font-semibold text-slate-100") { I18n.t("transactions.composite.split_purchase") }
            p(class: "text-xs text-slate-400") { I18n.t("transactions.composite.split_purchase_hint") }
          end
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

      div(
        class: "mt-4 space-y-3 #{'hidden' unless transaction.composite?}",
        data: { composite_transaction_target: "container" }
      ) do
        running_summary_bar
        div(class: "space-y-2", data: { composite_transaction_target: "itemsList" }) do
          render_existing_rows
        end
        render_template
        div(class: "flex justify-start pt-1") do
          Button(
            type: :button,
            variant: :outline,
            size: :sm,
            class: "gap-1 text-sm font-semibold",
            data: { action: "click->composite-transaction#addRow" }
          ) do
            cached_icon(:plus)
            span { I18n.t("transactions.composite.add_item") }
          end
        end
      end
    end
  end

  private

  def running_summary_bar
    div(class: "flex flex-wrap items-center justify-between gap-3 rounded-lg border border-slate-700/60 bg-slate-800/60 px-3 py-2 text-sm") do
      div(class: "flex items-center gap-4") do
        div(class: "flex items-center gap-1.5") do
          span(class: "text-slate-400 font-medium") { I18n.t("transactions.composite.parent_total") }
          span(class: "font-semibold text-slate-100 font-graduate dark:font-mono", data: { composite_transaction_target: "parentTotal" }) { "R$ 0,00" }
        end
        div(class: "flex items-center gap-1.5") do
          span(class: "text-slate-400 font-medium") { I18n.t("transactions.composite.allocated_sum") }
          span(class: "font-semibold text-slate-100 font-graduate dark:font-mono", data: { composite_transaction_target: "allocatedSum" }) { "R$ 0,00" }
        end
      end
      div do
        span(
          class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
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

      div(class: "w-full md:w-4/12") do
        item_form.text_field(
          :description,
          placeholder: I18n.t("activerecord.attributes.line_item.description"),
          class: "#{input_class_without_icon} h-10 px-3 py-2",
          autocomplete: "off"
        )
      end

      div(class: "w-full md:w-2/12") do
        item_form.text_field(
          :price,
          value: (item.price.present? && item.price != 0 ? item.price : nil),
          placeholder: I18n.t("activerecord.attributes.line_item.price"),
          inputmode: :numeric,
          class: "#{input_class_without_icon} h-10 px-3 py-2 font-graduate dark:font-mono sign-based",
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

      Button(
        type: :button,
        variant: :ghost,
        size: :icon,
        class: "text-red-400 hover:text-red-300 hover:bg-red-500/10 shrink-0",
        data: { action: "click->composite-transaction#removeRow" }
      ) do
        cached_icon(:destroy)
      end
    end
  end

  def row_class(item)
    "nested-line-item-row flex flex-col md:flex-row items-center gap-2 rounded-lg border border-slate-700/60 bg-slate-800/40 p-2 " \
      "#{'hidden' if item.marked_for_destruction?}"
  end

  def price_sign
    return "-" if transaction.is_a?(CardTransaction)

    transaction.price.to_i.negative? ? "-" : "+"
  end
end
