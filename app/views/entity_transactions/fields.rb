# frozen_string_literal: true

module Views
  module EntityTransactions
    class Fields < Components::Base
      include Phlex::Rails::Helpers::ImageTag
      include Phlex::Rails::Helpers::AssetPath

      include CacheHelper

      attr_reader :form, :transactable, :entity_transaction

      def initialize(form:)
        @form = form
        @transactable = form.options[:parent_builder].object
        @entity_transaction = form.object
      end

      def view_template
        div(class: "nested-form-wrapper",
            data: {
              new_record: entity_transaction.new_record?,
              reactive_form_target: "entityWrapper",
              controller: "entity-transaction",
              entity_transaction_form_index: form.index
            }) do
          div(class: "my-1 flex") do
            span(class: "flex items-center text-sm font-medium text-black dark:text-slate-100") do
              if transactable.is_a?(CashTransaction) && (transactable.card_payment? || transactable.card_advance? || transactable.exchange_return?)
                div(class: entity_chip_class) do
                  div(class: "flex items-center gap-2 flex-1") do
                    content
                  end
                end
              else
                Sheet(
                  class: "flex min-h-12 items-center rounded-lg border border-slate-400 px-2 py-1 text-sm text-black outline-none " \
                         "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700/50",
                  data: { ruby_ui__sheet_portal_value: true }
                ) do
                  SheetTrigger(class: "flex items-center gap-2 flex-1", data: { action: "click->reactive-form#syncPiggyBankMode" }) do
                    content
                  end

                  button(type: :button,
                         class: remove_button_class,
                         aria_label: "Remove",
                         data: { action: "reactive-form#removeEntity entity-transaction#checkForExchangeCategory" }) do
                    cached_icon(:little_x)
                  end

                  render Views::EntityTransactions::FieldsSheet.new(form:)
                end
              end
            end
          end

          form.hidden_field :entity_id, class: :entities_entity_id, data: { entity_transaction_target: "entitySelect" }
          form.hidden_field :id if entity_transaction.persisted?
          form.hidden_field :_destroy
        end
      end

      def content
        div(class: "entity_avatar_container") do
          image_tag(asset_path("avatars/#{entity_transaction.entity.avatar_name}"), class: "entity_avatar w-6 h-6 rounded-full") if entity_transaction.entity
        end

        span(class: "entities_entity_name text-nowrap") { entity_transaction.entity&.entity_name }
      end

      def entity_chip_class
        "flex min-h-12 items-center rounded-lg border border-slate-400 px-2 py-1 text-sm text-black outline-none " \
          "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
      end

      def remove_button_class
        "ms-2 inline-flex items-center rounded-xs bg-white p-1 text-sm text-black dark:bg-slate-900 dark:text-slate-300 " \
          "dark:hover:bg-slate-700 dark:hover:text-slate-100"
      end
    end
  end
end
