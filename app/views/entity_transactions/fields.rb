# frozen_string_literal: true

module Views
  module EntityTransactions
    class Fields < Components::Base
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::ImageTag

      include CacheHelper

      attr_reader :form, :entity_transaction

      def initialize(form:)
        @form = form
        @entity_transaction = form.object
      end

      def view_template
        div(class: "nested-form-wrapper",
            data: { new_record: entity_transaction.new_record?, reactive_form_target: "entityWrapper", controller: "entity-transaction" }) do
          div(class: "flex my-1") do
            span(class: "flex items-center text-sm font-medium text-black") do
              Sheet(class: "flex items-center px-2 py-1 rounded-lg border-1 border-slate-400 text-black outline-none text-sm") do
                SheetTrigger(class: "flex items-center gap-2 flex-1") do
                  div(class: "entity_avatar_container") do
                    if entity_transaction.entity
                      image_tag asset_path("avatars/#{entity_transaction.entity.avatar_name}"),
                                class: "entity_avatar w-6 h-6 rounded-full"
                    end
                  end

                  span(class: "entities_entity_name text-nowrap") { entity_transaction&.entity&.entity_name }
                end

                button(type: :button,
                       class: "inline-flex items-center p-1 ms-2 text-sm bg-white text-black rounded-xs",
                       aria_label: "Remove",
                       data: { action: "click->reactive-form#removeEntity" }) do
                  cached_icon(:little_x)
                end

                render Views::EntityTransactions::FieldsSheet.new(form:)
              end
            end

            form.hidden_field :entity_id, class: :entities_entity_id, data: { entity_transaction_target: "entitySelect" }
            form.hidden_field :_destroy
          end
        end
      end
    end
  end
end
