# frozen_string_literal: true

class Views::Budgets::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID
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
        id: :form,
        class: "contents text-black",
        data: { controller: "form-validate reactive-form price-mask dynamic-description", action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        hidden_field_tag :category_colours, categories_json, disabled: true, data: { reactive_form_target: :categoryColours }

        div(class: "w-full mb-6") do
          form.text_field \
            :description,
            autocomplete: :off,
            class: outdoor_readonly_input_class,
            data: { controller: "blinking-placeholder", text: model_attribute(budget, :description), dynamic_description_target: :description }
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "hw_category_id", class: "hw-cb w-full lg:w-1/4 mb-3 plus-icon") do
            bold_label(form, :categories)
            raw form.combobox \
              :budget_category, @categories,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(budget, :category_id),
              data: { action: "hw-combobox:selection->reactive-form#insertCategory hw-combobox:selection->dynamic-description#updateDescription",
                      value: ".hw-combobox__input" }
          end

          div(id: "hw_entity_id", class: "hw-cb w-full lg:w-1/4 mb-3 user-icon") do
            bold_label(form, :entities)
            raw form.combobox \
              :budget_entity,
              @entities,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(budget, :entity_id),
              data: { action: "hw-combobox:selection->dynamic-description#updateDescription", value: ".hw-combobox__input" }
          end

          div(class: "w-full lg:w-1/4 mb-2") do
            bold_label(form, :month_year)
            budget_date = budget.new_record? ? Date.current : Date.new(budget.year, budget.month, 1)
            TextField \
              form, :month_year,
              type: :month,
              svg: :calendar,
              class: "font-graduate",
              value: budget_date.strftime("%Y-%m"),
              data: { dynamic_description_target: :monthYear, action: "input->dynamic-description#updateDescription" }
          end

          div(class: "w-full lg:w-1/4 mb-2") do
            bold_label(form, :value)
            TextField \
              form,
              :value,
              svg: :money,
              class: "font-graduate",
              value: budget.value || -10_000,
              data: { dynamic_description_target: :value,
                      price_mask_target: :input, action: "input->price-mask#applyMask input->dynamic-description#updateDescription" }
          end
        end

        div(class: "flex items-center justify-center gap-2 w-1/4 mb-3 mx-auto") do
          div(class: "w-full lg:w-1/2 mb-2") do
            bold_label(form, :inclusive)
            div(class: "mb-3") do
              form.checkbox \
                :inclusive,
                class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500",
                checked: budget.new_record? || budget.active,
                data: { dynamic_description_target: :inclusive, action: "change->dynamic-description#updateDescription" }
            end
          end

          div(class: "w-full lg:w-1/2 mb-2") do
            bold_label(form, :active)
            div(class: "mb-3") do
              form.checkbox :active, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: budget.new_record? || budget.active
            end
          end
        end

        div(id: "categories_nested", class: "flex gap-2 overflow-x-auto pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data_nested_form_target: "template") do
            form.fields_for :budget_categories, BudgetCategory.new, child_index: "NEW_RECORD" do |budget_category_fields|
              render CategoryFields.new(form: budget_category_fields)
            end
          end

          budget_categories_association = budget.budget_categories.includes(:category) if budget.budget_categories.count > 1

          form.fields_for :budget_categories, budget_categories_association do |budget_category_fields|
            render CategoryFields.new(form: budget_category_fields)
          end

          div(data_nested_form_target: "target")

          link_to nil, nil, class: :hidden, data: { reactive_form_target: :addCategory, action: "nested-form#add" }
        end

        div(id: "entities_nested", class: "flex gap-2 overflow-x-auto pb-3",
            data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
          template(data_nested_form_target: "template") do
            form.fields_for :budget_entities, BudgetEntity.new, child_index: "NEW_RECORD" do |budget_entity_fields|
              render EntityFields.new(form: budget_entity_fields, entities:)
            end
          end

          budget_entities_association = budget.budget_entities.includes(:entity) if budget.budget_entities.count > 1

          form.fields_for :budget_entities, budget_entities_association do |budget_entity_fields|
            render EntityFields.new(form: budget_entity_fields, entities:)
          end

          div(data_nested_form_target: "target")

          link_to nil, nil, class: :hidden, data: { reactive_form_target: :addEntity, action: "nested-form#add" }
        end

        div(class: "#{budget.persisted? ? 'w-4/5' : 'w-2/5'} grid grid-cols-1 lg:flex items-center justify-between gap-2 mx-auto") do
          if budget.persisted?
            transaction = { category_id: budget.categories.map(&:id), entity_id: budget.entities.map(&:id) }

            render Components::ButtonComponent.new \
              link: search_card_transactions_path(card_transaction: transaction, format: :turbo_stream),
              options: { label: action_model(:index, CardTransaction, 2), colour: :indigo, data: { turbo_prefetch: false } }

            render Components::ButtonComponent.new \
              link: cash_transactions_path(cash_transaction: transaction, skip_budgets: true, format: :turbo_stream),
              options: { label: action_model(:index, CashTransaction, 2), colour: :indigo, data: { turbo_prefetch: false } }
          end

          render Components::ButtonComponent.new form:, options: { label: action_model(:submit, budget) }
          render Components::ButtonComponent.new link: budget,
                                                 options: {
                                                   id: "delete_budget_#{budget.id}",
                                                   label: action_model(:destroy, budget),
                                                   colour: :red,
                                                   data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
                                                 }
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  def categories_json
    current_user.categories.to_h do |c|
      [ c.id, c.bg_colour ]
    end.to_json
  end

  def entities_json
    current_user.entities.to_h do |c|
      [ c.id, asset_path("avatars/#{c.avatar_name}") ]
    end.to_json
  end
end
