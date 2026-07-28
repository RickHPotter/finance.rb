# frozen_string_literal: true

class Views::Categories::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include ComponentsHelper

  attr_reader :current_user, :category

  def initialize(current_user:, category:)
    @current_user = current_user
    @category = category
  end

  def view_template
    turbo_frame_tag dom_id(category) do
      form_url = category.persisted? ? category_path(category) : categories_path

      form_with(
        model: category,
        url: form_url,
        id: :form,
        class: "contents text-black",
        data: {
          controller: "reactive-form category-colour-preview",
          category_colour_preview_minimum_ratio_value: CategoryColours::Contrast::MINIMUM_RATIO,
          category_colour_preview_passing_label_value: colour_translation(:passing),
          category_colour_preview_failing_label_value: colour_translation(:failing),
          category_colour_preview_invalid_label_value: colour_translation(:invalid),
          category_colour_preview_suggestion_label_value: colour_translation(:suggestion),
          category_colour_preview_fallback_label_value: colour_translation(:fallback_label),
          action: "colour-picker:change->category-colour-preview#colourChanged"
        }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id

        div(class: "w-full mb-6") do
          form.text_field(
            :category_name,
            class: outdoor_input_class,
            autofocus: true,
            autocomplete: :off,
            disabled: category.persisted? && category.built_in?,
            value: category&.name,
            data: {
              controller: "blinking-placeholder",
              text: model_attribute(category, :category_name),
              category_colour_preview_target: "categoryNameInput",
              action: "input->category-colour-preview#nameChanged"
            }
          )
        end

        CategoryColourAccessibilityFields(form:, category:)

        bold_label(form, :active)

        div(class: "pb-3") do
          form.checkbox :active, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: category.new_record? || category.active
        end

        div(class: "flex w-full flex-col gap-3") do
          div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
            Button(type: :submit, class: "w-64 #{submit_button_class(form_action_mode(category))}") { action_message(:submit) }

            if category.persisted? && category.built_in == false
              Button(
                id: "delete_category_#{category.id}",
                type: :submit,
                variant: :outline,
                class: "w-64 #{destroy_button_class}",
                link: category_path(category),
                data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
              ) { action_message(:destroy) }
            end
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  private

  def colour_translation(key)
    I18n.t("categories.colour_accessibility.#{key}")
  end
end
