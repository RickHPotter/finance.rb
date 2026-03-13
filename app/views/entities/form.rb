# frozen_string_literal: true

class Views::Entities::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include ComponentsHelper

  attr_reader :current_user, :entity

  def initialize(current_user:, entity:)
    @current_user = current_user
    @entity = entity
  end

  def view_template
    turbo_frame_tag dom_id(entity) do
      form_url = entity.persisted? ? entity_path(entity) : entities_path

      form_with(model: entity, url: form_url, id: :form, class: "contents text-black", data: { controller: "reactive-form" }) do |form|
        form.hidden_field :user_id, value: current_user.id

        div(class: "w-full mb-6") do
          form.text_field(
            :entity_name,
            class: outdoor_input_class,
            autofocus: true,
            autocomplete: :off,
            data: { controller: "blinking-placeholder", text: model_attribute(entity, :entity_name) }
          )
        end

        div(class: "flex justify-center items-center mx-auto py-2") do
          IconPicker(form:, field: :avatar_name)
        end

        bold_label(form, :active)

        div(class: "pb-3") do
          form.checkbox :active, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: entity.new_record? || entity.active
        end

        div(class: "w-full") { render RubyUI::Button.new(type: :submit, variant: :purple) { action_model(:submit, entity) } }

        if entity.persisted?
          div(class: "w-full") do
            render RubyUI::Button.new(
              id: "delete_entity_#{entity.id}",
              type: :submit,
              variant: :destructive,
              link: entity_path(entity),
              data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
            ) { action_model(:destroy, entity) }
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end

    div(class: "text-xs font-thin text-slate-300 pt-2") do
      div do
        span { model_attribute(entity, :person_icons_credits) }
        a(class: "underline", href: "https://www.flaticon.com/authors/vitaly-gorbachev", title: "people icons") { "Vitaly Gorbachev - Flaticon" }
      end

      div do
        span { model_attribute(entity, :dog_icons_credits) }
        a(class: "underline", href: "https://www.flaticon.com/authors/maxim-kulikov", title: "dogs icons") { "Maxim Kulikov - Flaticon" }
      end
    end
  end
end
