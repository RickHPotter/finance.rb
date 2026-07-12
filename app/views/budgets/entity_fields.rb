# frozen_string_literal: true

class Views::Budgets::EntityFields < Components::Base
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include CacheHelper

  attr_reader :form, :budget_entity

  def initialize(form:)
    @form = form
    @budget_entity = form.object
  end

  def view_template
    div(class: "nested-form-wrapper",
        data: { new_record: budget_entity.new_record?, reactive_form_target: "entityWrapper" }) do
      div(class: "flex my-1") do
        span(class: "flex items-center text-sm font-medium text-black dark:text-slate-100") do
          div(class: entity_chip_class) do
            div(class: "flex items-center gap-2 flex-1") do
              div(class: "entity_avatar_container") do
                image_tag asset_path("avatars/#{budget_entity.entity.avatar_name}"), class: "entity_avatar w-6 h-6 rounded-full" if budget_entity.entity
              end

              span(class: "entities_entity_name text-black text-nowrap dark:text-slate-100", data: { dynamic_description_target: :entity }) do
                budget_entity&.entity&.entity_name
              end
            end

            button(type: :button,
                   class: remove_button_class,
                   aria_label: "Remove",
                   data: { action: "click->reactive-form#removeEntity dynamic-description#updateDescription" }) do
              cached_icon(:little_x)
            end
          end
        end

        form.hidden_field :entity_id, class: :entities_entity_id
        form.hidden_field :id if budget_entity.persisted?
        form.hidden_field :_destroy
      end
    end
  end

  private

  def entity_chip_class
    "flex min-h-12 items-center rounded-lg border border-slate-400 px-2 py-1 text-sm text-black outline-none " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
  end

  def remove_button_class
    "ms-2 inline-flex items-center rounded-xs bg-white p-1 text-sm text-black dark:bg-slate-900 dark:text-slate-300 " \
      "dark:hover:bg-slate-700 dark:hover:text-slate-100"
  end
end
