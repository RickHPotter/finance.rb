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
      class: "border-y py-2 md:border-r md:pr-2 dark:border-slate-700/50",
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

      div(class: "grid min-h-[3.5rem] grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        Button(
          type: :button,
          variant: :outline,
          class: carousel_button_class,
          data: {
            form_collection_carousel_target: "prevButton",
            action: "click->form-collection-carousel#scrollPrev"
          }
        ) { "←" }

        div(class: "min-h-[3.5rem] overflow-hidden", data: { form_collection_carousel_target: "viewport" }) do
          div(class: "flex min-h-[3.5rem] -ml-2 items-center", data: { nested_form_target: "target", nested_form_insert: "beforeend" }) do
            form.fields_for :category_transactions, category_transactions_association, include_id: false do |category_transaction_fields|
              render_item(category_transaction_fields)
            end
          end
        end

        Button(
          type: :button,
          variant: :outline,
          class: carousel_button_class,
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

  def carousel_button_class
    "h-full min-h-12 w-full border border-slate-300 bg-white px-0 text-sm text-slate-700 hover:bg-slate-100 hover:text-slate-950 " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-400 dark:hover:bg-slate-700/70 dark:hover:text-slate-100"
  end

  def category_transactions_association
    association = transaction.category_transactions.includes(:category)
    association if association.exists?
  end

  def render_item(category_transaction_fields)
    div(class: "min-w-0 shrink-0 max-w-full pl-2") do
      render Views::CategoryTransactions::Fields.new(form: category_transaction_fields)
    end
  end
end
