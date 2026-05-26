# frozen_string_literal: true

class Views::Budgets::FormCategoriesSection < Views::Base
  attr_reader :form, :budget

  def initialize(form:, budget:)
    @form = form
    @budget = budget
  end

  def view_template
    div(
      id: "categories_nested",
      class: "border-y py-2 md:border-r md:pr-2",
      data: {
        controller: "nested-form form-collection-carousel",
        nested_form_wrapper_selector_value: ".nested-form-wrapper"
      }
    ) do
      template(data_nested_form_target: "template") do
        form.fields_for :budget_categories, BudgetCategory.new, child_index: "NEW_RECORD" do |budget_category_fields|
          render_item(budget_category_fields)
        end
      end

      div(class: "grid min-h-[3.5rem] grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        Button(
          type: :button,
          variant: :outline,
          class: "h-full min-h-12 w-full border border-slate-200 bg-slate-50 px-0 text-sm",
          data: {
            form_collection_carousel_target: "prevButton",
            action: "click->form-collection-carousel#scrollPrev"
          }
        ) { "←" }

        div(class: "min-h-[3.5rem] overflow-hidden", data: { form_collection_carousel_target: "viewport" }) do
          div(class: "flex min-h-[3.5rem] -ml-2 items-center", data: { nested_form_target: "target", nested_form_insert: "beforeend" }) do
            form.fields_for :budget_categories, budget_categories_association, include_id: false do |budget_category_fields|
              render_item(budget_category_fields)
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

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addCategory, action: "nested-form#add" })
    end
  end

  private

  def budget_categories_association
    association = budget.budget_categories.includes(:category)
    association if association.exists?
  end

  def render_item(budget_category_fields)
    div(class: "min-w-0 shrink-0 max-w-full pl-2") do
      render Views::Budgets::CategoryFields.new(form: budget_category_fields)
    end
  end
end
