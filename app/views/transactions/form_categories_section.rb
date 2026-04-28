# frozen_string_literal: true

class Views::Transactions::FormCategoriesSection < Views::Base
  attr_reader :form, :transaction

  def initialize(form:, transaction:)
    @form = form
    @transaction = transaction
  end

  def view_template
    div(
      id: "categories_nested",
      class: "border-y border-r border-purple-200 py-2 pr-2",
      data: {
        controller: "nested-form form-collection-carousel",
        nested_form_wrapper_selector_value: ".nested-form-wrapper"
      }
    ) do
      template(data_nested_form_target: "template") do
        form.fields_for :category_transactions, CategoryTransaction.new, child_index: "NEW_RECORD" do |category_transaction_fields|
          render_item(category_transaction_fields)
        end
      end

      div(class: "grid grid-cols-[1.875rem_minmax(0,1fr)_1.875rem] items-stretch gap-2") do
        Button(
          type: :button,
          variant: :outline,
          class: "h-full min-h-12 w-full rounded-xl border border-slate-300 px-0 text-base",
          data: {
            form_collection_carousel_target: "prevButton",
            action: "click->form-collection-carousel#scrollPrev"
          }
        ) { "←" }

        div(class: "overflow-hidden", data: { form_collection_carousel_target: "viewport" }) do
          div(class: "flex -ml-2", data: { nested_form_target: "target", nested_form_insert: "beforeend" }) do
            form.fields_for :category_transactions, category_transactions_association, include_id: false do |category_transaction_fields|
              render_item(category_transaction_fields)
            end
          end
        end

        Button(
          type: :button,
          variant: :outline,
          class: "h-full min-h-12 w-full rounded-xl border border-slate-300 px-0 text-base",
          data: {
            form_collection_carousel_target: "nextButton",
            action: "click->form-collection-carousel#scrollNext"
          }
        ) { "→" }
      end

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addCategory, action: "nested-form#add" })
    end
  end

  private

  def category_transactions_association
    transaction.category_transactions.includes(:category) if transaction.category_transactions.count > 1
  end

  def render_item(category_transaction_fields)
    div(class: "min-w-0 shrink-0 max-w-full pl-2") do
      render Views::CategoryTransactions::Fields.new(form: category_transaction_fields)
    end
  end
end
