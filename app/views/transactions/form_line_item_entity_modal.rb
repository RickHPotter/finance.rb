# frozen_string_literal: true

class Views::Transactions::FormLineItemEntityModal < Views::Base
  include Phlex::Rails::Helpers::FieldsFor
  include ComponentsHelper
  include TranslateHelper
  include CacheHelper

  attr_reader :form, :transaction

  def initialize(form:, transaction:)
    @form = form
    @transaction = transaction
  end

  def view_template
    SheetContent(
      side: :middle,
      class: "h-[94vh] w-[96vw] max-w-5xl mx-auto rounded-xl border border-slate-300 text-black overflow-hidden flex flex-col",
      data: { composite_entity_modal_target: "content" }
    ) do
      SheetHeader do
        SheetTitle(class: "text-black dark:text-white", data: { composite_entity_modal_target: "title" }) do
          I18n.t("transactions.composite.entity_modal_title")
        end
        SheetDescription { I18n.t("transactions.composite.entity_modal_description") }
      end

      SheetMiddle(class: "min-h-0 flex-1 overflow-y-auto px-4") do
        div(class: "mb-3 rounded-lg border border-slate-200 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-800/50") do
          span(class: "text-sm text-slate-500 dark:text-slate-400") { I18n.t("transactions.composite.entity_modal_total") }
          span(class: "ml-2 font-graduate font-semibold dark:font-mono", data: { composite_entity_modal_target: "aggregate" }) { "R$ 0,00" }
        end

        div(class: "space-y-4", data: { composite_entity_modal_target: "groups" }) do
          existing_groups
        end

        template(data: { composite_entity_modal_target: "template" }) do
          form.fields_for :line_items, LineItem.new, child_index: "NEW_LINE_ITEM" do |item_form|
            render_item_group(item_form, LineItem.new, "NEW_LINE_ITEM")
          end
        end
      end
    end
  end

  private

  def existing_groups
    items = transaction.line_items.to_a
    items = [ LineItem.new ] if items.empty?

    items.each_with_index do |item, index|
      form.fields_for :line_items, item, child_index: index do |item_form|
        render_item_group(item_form, item, index)
      end
    end
  end

  def render_item_group(item_form, item, index)
    entity_transaction = item.entity_transactions.reject(&:marked_for_destruction?).first ||
                         EntityTransaction.new(entity: item.entity, price: item.price.to_i, price_to_be_returned: 0, is_payer: false)

    item_form.fields_for :entity_transactions, entity_transaction, child_index: 0 do |entity_form|
      div(
        class: "hidden rounded-lg border border-slate-200 p-3 dark:border-slate-700",
        data: {
          controller: "entity-transaction price-mask",
          composite_entity_modal_target: "group",
          line_item_key: index.to_s,
          entity_id: item.entity_id.to_s,
          line_item_price: item.price.to_i,
          transaction_total_cents: -item.price.to_i
        }
      ) do
        entity_form.hidden_field :id if entity_transaction.persisted?
        entity_form.hidden_field :is_payer, value: entity_transaction.is_payer, data: { entity_transaction_target: "payerInput" }
        entity_form.hidden_field :price, value: item.price.to_i, data: { entity_transaction_target: "priceInput" }
        entity_form.hidden_field :_destroy, value: item.entity_id.present? ? "false" : "true"

        div(class: "mb-3 flex items-center justify-between gap-2") do
          div do
            p(class: "font-medium text-slate-900 dark:text-slate-100") do
              item.description.presence || I18n.t("activerecord.models.line_item.one")
            end
            p(class: "text-xs text-slate-500 dark:text-slate-400", data: { composite_entity_modal_target: "itemPrice" }) do
              ActiveSupport::NumberHelper.number_to_currency(item.price.to_i / 100.0, unit: "R$ ")
            end
          end
        end

        div(class: "grid grid-cols-1 gap-3 md:grid-cols-4") do
          div do
            label(for: "line_item_return_#{index}", class: label_class) { model_attribute(EntityTransaction, :price_to_be_returned) }
            entity_form.text_field(
              :price_to_be_returned,
              id: "line_item_return_#{index}",
              value: entity_transaction.price_to_be_returned,
              inputmode: :numeric,
              class: input_class,
              data: {
                controller: "input-select",
                price_mask_target: :input,
                sign: item.price.to_i.positive? ? "-" : "+",
                entity_transaction_target: :priceToBeReturnedInput,
                action: "input->price-mask#applyMask input->entity-transaction#updatePayer input->entity-transaction#toggleExchanges"
              }
            )
          end

          div do
            label(for: "line_item_return_percentage_#{index}", class: label_class) { model_attribute(EntityTransaction, :loan_return_percentage) }
            entity_form.number_field(
              :loan_return_percentage,
              id: "line_item_return_percentage_#{index}",
              min: 0,
              step: "0.0001",
              class: input_class,
              data: {
                entity_transaction_target: :loanReturnPercentageInput,
                original_value: entity_transaction.loan_return_percentage,
                action: "input->entity-transaction#applyLoanReturnPercentage"
              }
            )
          end

          div do
            label(for: "line_item_exchanges_count_#{index}", class: label_class) { model_attribute(EntityTransaction, :exchanges_count) }
            entity_form.number_field(
              :exchanges_count,
              id: "line_item_exchanges_count_#{index}",
              min: 0,
              max: 72,
              value: entity_transaction.exchanges_count.to_i,
              class: input_class,
              data: {
                entity_transaction_target: :exchangesCountInput,
                action: "input->entity-transaction#updateExchangesPrices"
              }
            )
          end

          div(class: "flex items-end") do
            Button(
              type: :button,
              class: "h-10 w-full rounded-md border border-slate-300 px-3 text-sm dark:border-slate-700",
              data: { action: "click->entity-transaction#automaticLineItemRepayment" }
            ) { I18n.t("transactions.composite.automatic") }
          end
        end

        exchange_fields(entity_form, entity_transaction, index)
      end
    end
  end

  def exchange_fields(entity_form, entity_transaction, index)
    div(
      class: "mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3",
      data: {
        controller: "nested-form exchange-lock",
        nested_form_wrapper_selector_value: ".nested-exchange-wrapper",
        entity_transaction_target: "exchangeList"
      }
    ) do
      template(data_nested_form_target: "template") do
        entity_form.fields_for :exchanges, Exchange.new, child_index: "NEW_NESTED_RECORD" do |exchange_form|
          render Views::Exchanges::Fields.new(form: exchange_form, bound_type: :standalone, id_prefix: "line_item_#{index}")
        end
      end

      entity_transaction.exchanges.reject(&:marked_for_destruction?).sort_by(&:number).each do |exchange|
        entity_form.fields_for :exchanges, exchange do |exchange_form|
          render Views::Exchanges::Fields.new(form: exchange_form, bound_type: :standalone, id_prefix: "line_item_#{index}")
        end
      end

      div(data_nested_form_target: "target")
      button(type: :button, class: :hidden, tabindex: -1, data: { entity_transaction_target: "addExchange", action: "nested-form#addChildNested" })
    end
  end

  def label_class
    "mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300"
  end

  def input_class
    "w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
  end
end
