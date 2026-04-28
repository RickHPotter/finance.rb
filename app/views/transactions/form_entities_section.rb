# frozen_string_literal: true

class Views::Transactions::FormEntitiesSection < Views::Base
  attr_reader :form, :transaction

  def initialize(form:, transaction:)
    @form = form
    @transaction = transaction
  end

  def view_template
    div(
      id: "entities_nested",
      class: "border-y py-2 md:border-l md:pl-2",
      data: {
        controller: "nested-form form-collection-carousel",
        nested_form_wrapper_selector_value: ".nested-form-wrapper"
      }
    ) do
      template(data_nested_form_target: "template") do
        form.fields_for :entity_transactions, EntityTransaction.new, child_index: "NEW_RECORD" do |entity_transaction_fields|
          render_item(entity_transaction_fields)
        end
      end

      div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        Button(
          type: :button,
          variant: :outline,
          class: "h-full min-h-12 w-full border border-slate-200 bg-slate-50 px-0 text-sm",
          data: {
            form_collection_carousel_target: "prevButton",
            action: "click->form-collection-carousel#scrollPrev"
          }
        ) { "←" }

        div(class: "overflow-hidden", data: { form_collection_carousel_target: "viewport" }) do
          div(class: "flex -ml-2", data: { nested_form_target: "target", nested_form_insert: "beforeend" }) do
            form.fields_for :entity_transactions, entity_transactions_association, include_id: false do |entity_transaction_fields|
              render_item(entity_transaction_fields)
            end
          end
        end

        Button(
          type: :button,
          variant: :outline,
          class: "h-full min-h-12 w-full border border-slate-200 bg-slate-50 px-0 text-sm",
          data: {
            form_collection_carousel_target: "nextButton",
            action: "click->form-collection-carousel#scrollNext"
          }
        ) { "→" }
      end

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
    end
  end

  private

  def entity_transactions_association
    transaction.entity_transactions.includes(:entity, :exchanges) if transaction.entity_transactions.count > 1
  end

  def render_item(entity_transaction_fields)
    div(class: "min-w-0 shrink-0 max-w-full pl-2") do
      render Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
    end
  end
end
