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

      form_with(model: category, url: form_url, id: :form, class: "contents text-black", data: { controller: "reactive-form" }) do |form|
        form.hidden_field :user_id, value: current_user.id

        div(class: "w-full mb-6") do
          form.text_field(
            :category_name,
            class: outdoor_input_class,
            autofocus: true,
            autocomplete: :off,
            disabled: category.persisted? && category.built_in?,
            value: category&.name,
            data: { controller: "blinking-placeholder", text: model_attribute(category, :category_name) }
          )
        end

        div(class: "flex justify-center items-center mx-auto py-2") do
          ColourPicker(form:, field: :colour)
        end

        bold_label(form, :active)

        div(class: "pb-3") do
          form.checkbox :active, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: category.new_record? || category.active
        end

        div(class: "w-full") { Button(type: :submit, variant: :purple) { action_model(:submit, category) } }

        if category.persisted? && category.built_in == false
          div(class: "w-full") do
            Button(
              id: "delete_category_#{category.id}",
              type: :submit,
              variant: :destructive,
              link: category_path(category),
              data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
            ) { action_model(:destroy, category) }
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end
end
