# frozen_string_literal: true

module Views
  module EntityTransactions
    class FieldsSheet < Components::Base
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::ImageTag
      include Phlex::Rails::Helpers::RadioButtonTag

      include ComponentsHelper
      include TranslateHelper
      include CacheHelper

      attr_reader :form, :entity_transaction

      def initialize(form:)
        @form = form
        @entity_transaction = form.object
      end

      def view_template
        SheetContent(side: :top, class: "max-w-sm md:max-w-2xl mx-auto", data: { controller: "price-mask" }) do
          SheetHeader do
            SheetTitle(class: "entities_entity_name") { entity_transaction&.entity&.entity_name }
            SheetDescription { "" }
          end

          SheetMiddle do
            div(class: "grid grid-cols-2 justify-center") do
              bold_label(form, :price, "entity_transaction_price_#{form.index}")
              bold_label(form, :price_to_be_returned, "entity_transaction_price_to_be_returned_#{form.index}")
            end

            div(class: "grid grid-cols-12 justify-center gap-1 pb-3") do
              div(class: "col-span-5") do
                TextField form, :price,
                          svg: :money,
                          id: "entity_transaction_price_#{form.index}",
                          class: "font-graduate dynamic-price",
                          data: { price_mask_target: :input,
                                  entity_transaction_target: :priceInput,
                                  action: "input->price-mask#applyMask input->entity-transaction#updatePrice" }
              end

              render_helper_popover(target: :priceInput,             icon: :arrow_down_left_micro)
              render_helper_popover(target: :priceToBeReturnedInput, icon: :arrow_down_right_micro)

              div(class: "col-span-5") do
                TextField form, :price_to_be_returned,
                          svg: :money,
                          id: "entity_transaction_price_to_be_returned_#{form.index}",
                          class: "font-graduate dynamic-price",
                          data: { price_mask_target: :input,
                                  entity_transaction_target: :priceToBeReturnedInput,
                                  action: "input->price-mask#applyMask input->entity-transaction#updatePrice input->entity-transaction#toggleExchanges" }
              end
            end

            div(class: "grid grid-cols-4") do
              div(class: "col-span-2") do
                bold_label(form, :exchanges_count, "entity_transaction_exchanges_count_#{form.index}")
              end

              bold_label(form, :standalone, "entity_transaction_standalone_#{form.index}")
              bold_label(form, :card_bound, "entity_transaction_standalone_#{form.index}")
            end

            div(class: "grid grid-cols-4 gap-1") do
              div(class: "col-span-2") do
                TextField form, :exchanges_count,
                          type: :number,
                          svg: :number,
                          min: 0, max: 72,
                          disabled: !entity_transaction.is_payer,
                          value: entity_transaction&.exchanges_count&.to_i,
                          id: "entity_transaction_exchanges_count_#{form.index}",
                          class: "font-graduate #{'opacity-50' unless entity_transaction.is_payer}",
                          data: { entity_transaction_target: :exchangesCountInput, action: "input->entity-transaction#updateExchangesPrices" }
              end

              radio_button_tag(:bound_type, :standalone,
                               checked: entity_transaction.exchanges.first&.standalone? || !entity_transaction.exchanges.first&.card_bound?,
                               id: "entity_transaction_standalone_#{form.index}",
                               class: "w-4 h-4 border-gray-300 focus:ring-blue-500 m-auto",
                               data: { entity_transaction_target: :boundType, action: "entity-transaction#fillInBoundType" })

              radio_button_tag(:bound_type, :card_bound,
                               checked: entity_transaction.exchanges.first&.card_bound?,
                               id: "entity_transaction_card_bound_#{form.index}",
                               class: "w-4 h-4 border-gray-300 focus:ring-blue-500 m-auto",
                               data: { entity_transaction_target: :boundType, action: "entity-transaction#fillInBoundType" })
            end

            div(id: "exchanges_nested", data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
              template(data: { nested_form_target: "template" }) do
                form.fields_for :exchanges, Exchange.new, child_index: "NEW_NESTED_RECORD" do |exchange_fields|
                  render ::Views::Exchanges::Fields.new(form: exchange_fields)
                end
              end

              exchanges_association = entity_transaction.exchanges.includes(:cash_transaction) if entity_transaction.exchanges.count > 1
              form.fields_for :exchanges, exchanges_association do |exchange_fields|
                render ::Views::Exchanges::Fields.new(form: exchange_fields)
              end

              div(data: { nested_form_target: "target" })

              button(class: :hidden, data: { entity_transaction_target: :addExchange, action: "nested-form#addChildNested" })
            end

            SheetFooter do
              # Button(variant: :outline, data: { action: "click->ruby-ui--sheet-content#close" }) { "Cancel" }
              # Button(type: "submit") { "Save" }
            end
          end
        end
      end

      def render_helper_popover(target:, icon:)
        Popover(class: "m-auto") do
          PopoverTrigger(class: "w-full") do
            Button(class: "bg-gray-100 rounded-sm") do
              cached_icon(icon)
            end
          end

          PopoverContent(class: "w-40") do
            Button(class: "w-full justify-start pl-2", data: { action: "entity-transaction#fillPrice", divider: 1, target: }) do
              "Full Price"
            end

            Button(class: "w-full justify-start pl-2", data: { action: "entity-transaction#fillPrice", divider: 2, target: }) do
              "Half Price"
            end

            Button(class: "w-full justify-start pl-2", data: { action: "entity-transaction#fillPrice", divider: 3, target: }) do
              "Third Price"
            end
          end
        end
      end
    end
  end
end
