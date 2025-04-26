# frozen_string_literal: true

module Views
  module Budgets
    class EntityFields < Components::Base
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::ImageTag

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
            span(class: "flex items-center text-sm font-medium text-black") do
              div(class: "flex items-center px-2 py-1 rounded-lg border-1 border-slate-400 text-black outline-none text-sm") do
                div(class: "flex items-center gap-2 flex-1") do
                  div(class: "entity_avatar_container") do
                    image_tag asset_path("avatars/#{budget_entity.entity.avatar_name}"), class: "entity_avatar w-6 h-6 rounded-full" if budget_entity.entity
                  end

                  span(class: "entities_entity_name text-black text-nowrap", data: { dynamic_description_target: :entity }) do
                    budget_entity&.entity&.entity_name
                  end
                end

                button(type: :button,
                       class: "inline-flex items-center p-1 ms-2 text-sm bg-white text-black rounded-xs",
                       aria_label: "Remove",
                       data: { action: "click->reactive-form#removeEntity" }) do
                  cached_icon(:little_x)
                end
              end
            end

            form.hidden_field :entity_id, class: :entities_entity_id
            form.hidden_field :_destroy
          end
        end
      end
    end
  end
end
