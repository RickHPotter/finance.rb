# frozen_string_literal: true

module Views
  module EntityTransactions
    class FieldsSheet < Components::Base
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::ImageTag
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

          SheetMiddle(class: "grid grid-cols-2 gap-4") do
            div(class: "container") do
              bold_label(form, :price, "entity_transaction_price_#{form.index}")
              TextField  form, :price,
                         svg: :money,
                         id: "entity_transaction_price_#{form.index}",
                         class: "font-graduate",
                         data: { price_mask_target: :input,
                                 reactive_form_target: :priceInput,
                                 entity_transaction_target: :priceInput,
                                 action: "input->price-mask#applyMask input->entity-transaction#updatePrice" }
            end

            div(class: "container") do
              bold_label(form, :price_to_be_returned, "entity_transaction_price_to_be_returned_#{form.index}")
              TextField form, :price_to_be_returned,
                        svg: :money,
                        id: "entity_transaction_price_to_be_returned_#{form.index}",
                        class: "font-graduate",
                        data: { price_mask_target: :input,
                                reactive_form_target: :priceInput,
                                entity_transaction_target: :priceToBeReturnedInput,
                                action: "input->price-mask#applyMask input->entity-transaction#updatePrice input->entity-transaction#toggleExchanges" }
            end

            div(class: "container") do
              button(type: :button, class: "bg-slate-800 text-white font-bold p-1 border-2 border-red-300 rounded-sm shadow-sm",
                     data: { action: "entity-transaction#fillPrice", divider: 1 }) { "1/1 " }
              button(type: :button, class: "bg-slate-800 text-white font-bold p-1 border-2 border-green-300 rounded-sm shadow-sm",
                     data: { action: "entity-transaction#fillPrice", divider: 2 }) { "1/2 " }
              button(type: :button, class: "bg-slate-800 text-white font-bold p-1 border-2 border-blue-300 rounded-sm shadow-sm",
                     data: { action: "entity-transaction#fillPrice", divider: 3 }) { "1/3 " }
            end

            div(class: "container") do
              bold_label(form, :exchanges_count, "entity_transaction_exchanges_count_#{form.index}")

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

            div(id: "exchanges_nested", data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
              template(data: { nested_form_target: "template" }) do
                form.fields_for :exchanges, Exchange.new, child_index: "NEW_RECORD" do |exchange_fields|
                  render ::Views::Exchanges::Fields.new(form: exchange_fields)
                end
              end

              exchanges_association = entity_transaction.exchanges.includes(:cash_transaction) if entity_transaction.exchanges.count > 1
              form.fields_for :exchanges, exchanges_association do |exchange_fields|
                render ::Views::Exchanges::Fields.new(form: exchange_fields)
              end

              div(data: { nested_form_target: "target" })

              button(class: :hidden, data: { entity_transaction_target: :addExchange, action: "nested-form#addChildNested " })
            end

            SheetFooter do
              # Button(variant: :outline, data: { action: "click->ruby-ui--sheet-content#close" }) { "Cancel" }
              # Button(type: "submit") { "Save" }
            end
          end
        end
      end
    end
  end
end
