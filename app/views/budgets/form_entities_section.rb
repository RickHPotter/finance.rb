# frozen_string_literal: true

class Views::Budgets::FormEntitiesSection < Views::Base
  attr_reader :form, :budget

  def initialize(form:, budget:)
    @form = form
    @budget = budget
  end

  def view_template
    div(
      id: "entities_nested",
      class: "border-y py-2 md:border-l md:pl-2 dark:border-slate-700/50",
      data: {
        controller: "nested-form form-collection-carousel",
        nested_form_wrapper_selector_value: ".nested-form-wrapper"
      }
    ) do
      template(data_nested_form_target: "template") do
        form.fields_for :budget_entities, BudgetEntity.new, child_index: "NEW_RECORD" do |budget_entity_fields|
          render_item(budget_entity_fields)
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
            form.fields_for :budget_entities, budget_entities_association, include_id: false do |budget_entity_fields|
              render_item(budget_entity_fields)
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

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
    end
  end

  private

  def carousel_button_class
    "h-full min-h-12 w-full border border-slate-200 bg-slate-50 px-0 text-sm text-slate-700 hover:bg-slate-100 hover:text-slate-950 " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-400 dark:hover:bg-slate-700/70 dark:hover:text-slate-100"
  end

  def budget_entities_association
    association = budget.budget_entities.includes(:entity)
    association if association.exists?
  end

  def render_item(budget_entity_fields)
    div(class: "min-w-0 shrink-0 max-w-full pl-2") do
      render Views::Budgets::EntityFields.new(form: budget_entity_fields)
    end
  end
end
