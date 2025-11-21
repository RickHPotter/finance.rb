# frozen_string_literal: true

module Views
  module EntityTransactions
    class FieldsSheet < Components::Base
      include Phlex::Rails::Helpers::ImageTag
      include Phlex::Rails::Helpers::AssetPath
      include Phlex::Rails::Helpers::RadioButtonTag

      include ComponentsHelper
      include TranslateHelper
      include CacheHelper

      attr_reader :form, :transactable, :entity_transaction

      def initialize(form:)
        @form = form
        @transactable = form.options[:parent_builder].object
        @entity_transaction = form.object
      end

      def view_template
        positive = transactable.price.to_i.positive?
        sign = positive ? "-" : "+"

        SheetContent(side: :top, class: "max-w-sm md:max-w-3xl lg:max-w-4xl mx-auto", data: { controller: "price-mask" }) do
          SheetHeader do
            SheetTitle(class: "entities_entity_name") { entity_transaction&.entity&.entity_name }
            SheetDescription { "" }
          end

          SheetMiddle do
            div(class: "grid grid-cols-1 lg:grid-cols-2 justify-center gap-3 pb-3") do
              div do
                bold_label(form, :price, "entity_transaction_price_#{form.index}")

                div(class: "flex gap-1 justify-between") do
                  div(class: "flex-1") do
                    TextField \
                      form, :price,
                      svg: :money,
                      id: "entity_transaction_price_#{form.index}",
                      class: "font-graduate dynamic-price",
                      onclick: "this.select();",
                      data: { price_mask_target: :input,
                              entity_transaction_target: :priceInput,
                              action: "input->price-mask#applyMask input->entity-transaction#updatePrice",
                              sign: }
                  end

                  render_helper_popover(target: :priceInput, icon: :arrow_down_left)
                end
              end

              div do
                bold_label(form, :price_to_be_returned, "entity_transaction_price_to_be_returned_#{form.index}")

                div(class: "flex gap-1 justify-between") do
                  div(class: "flex-1") do
                    TextField \
                      form, :price_to_be_returned,
                      svg: :money,
                      id: "entity_transaction_price_to_be_returned_#{form.index}",
                      class: "font-graduate dynamic-price",
                      onclick: "this.select();",
                      data: { price_mask_target: :input,
                              entity_transaction_target: :priceToBeReturnedInput,
                              action: "input->price-mask#applyMask input->entity-transaction#updatePrice input->entity-transaction#toggleExchanges",
                              sign: }
                  end

                  render_helper_popover(target: :priceToBeReturnedInput, icon: :arrow_down_left)
                end
              end

              div do
                bold_label(form, :exchanges_count, "entity_transaction_exchanges_count_#{form.index}")

                div(class: "flex gap-1 justify-between") do
                  div(class: "flex-1") do
                    TextFieldTag :exchanges_count,
                                 type: :number,
                                 svg: :number,
                                 min: 0, max: 72,
                                 disabled: !entity_transaction.is_payer,
                                 value: entity_transaction&.exchanges_count&.to_i,
                                 id: "entity_transaction_exchanges_count_#{form.index}",
                                 class: "font-graduate #{'opacity-50' unless entity_transaction.is_payer}",
                                 onclick: "this.select();",
                                 data: { entity_transaction_target: :exchangesCountInput, action: "input->entity-transaction#updateExchangesPrices" }
                  end

                  div(class: "m-auto") do
                    Button(
                      class: "bg-gray-100 rounded-sm", disabled: !entity_transaction.is_payer,
                      data: { entity_transaction_target: :exchangesCountEqualsButton, action: "entity-transaction#copyTransactionInstallmentsCount" }
                    ) do
                      cached_icon(:equals)
                    end
                  end
                end
              end

              if transactable.is_a? CardTransaction
                div(class: "") do
                  bold_label(form, :bound_type, "entity_transaction_bound_type_#{form.index}")

                  div(class: "flex justify-start gap-1") do
                    label(
                      for: "entity_transaction_standalone_#{form.index}",
                      class: "flex items-center gap-2 px-3 py-2 border rounded-md cursor-pointer select-none transition-all duration-200
                              text-sm font-medium border-gray-300 bg-white text-gray-700 hover:border-blue-400 hover:bg-blue-50
                              has-[:checked]:border-blue-600 has-[:checked]:bg-blue-100 has-[:checked]:text-blue-700"
                    ) do
                      radio_button_tag("bound_type_#{form.index}", :standalone,
                                       checked: entity_transaction.new_record? || entity_transaction.exchanges.first&.standalone?,
                                       id: "entity_transaction_standalone_#{form.index}",
                                       class: "w-4 h-4 text-blue-600 focus:ring-blue-500 cursor-pointer",
                                       data: { entity_transaction_target: :boundType, action: "entity-transaction#fillInBoundType" })

                      span { model_attribute(form.object, :standalone).downcase }
                    end

                    label(
                      for: "entity_transaction_card_bound_#{form.index}",
                      class: "flex items-center gap-2 px-3 py-2 border rounded-md cursor-pointer select-none transition-all duration-200
                              text-sm font-medium border-gray-300 bg-white text-gray-700 hover:border-blue-400 hover:bg-blue-50
                              has-[:checked]:border-blue-600 has-[:checked]:bg-blue-100 has-[:checked]:text-blue-700"
                    ) do
                      radio_button_tag("bound_type_#{form.index}", :card_bound,
                                       checked: entity_transaction.exchanges.first&.card_bound?,
                                       id: "entity_transaction_card_bound_#{form.index}",
                                       class: "w-4 h-4 text-blue-600 focus:ring-blue-500 cursor-pointer",
                                       data: { entity_transaction_target: :boundType, action: "entity-transaction#fillInBoundType" })

                      span { model_attribute(form.object, :card_bound).downcase }
                    end
                  end
                end
              end
            end

            div(
              id: "exchanges_nested",
              class: "overflow-y-auto max-h-[calc(100vh-22rem)] pt-2 grid grid-cols-1 sm:grid-cols-2 gap-3 pb-3 sm:max-h-[calc(100vh-12rem)]",
              data: { controller: "nested-form exchange-lock", nested_form_wrapper_selector_value: ".nested-exchange-wrapper" }
            ) do
              template(data_nested_form_target: "template") do
                form.fields_for :exchanges, Exchange.new, child_index: "NEW_NESTED_RECORD" do |exchange_fields|
                  render ::Views::Exchanges::Fields.new(form: exchange_fields)
                end
              end

              exchanges_association = entity_transaction.exchanges.includes(:cash_transaction).order(:number) if entity_transaction.exchanges.count > 1
              form.fields_for :exchanges, exchanges_association do |exchange_fields|
                render ::Views::Exchanges::Fields.new(form: exchange_fields)
              end

              div(data_nested_form_target: "target")

              button(type: :button, class: :hidden, tabindex: -1, data: { entity_transaction_target: :addExchange, action: "nested-form#addChildNested" })
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
            Button(variant: :ghost, class: "w-full justify-start pl-2", data: { action: "entity-transaction#fillPrice", divider: 1, target: }) do
              model_attribute(Exchange, :full_price)
            end

            Button(variant: :ghost, class: "w-full justify-start pl-2", data: { action: "entity-transaction#fillPrice", divider: 2, target: }) do
              model_attribute(Exchange, :half_price)
            end

            Button(variant: :ghost, class: "w-full justify-start pl-2", data: { action: "entity-transaction#fillPrice", divider: 3, target: }) do
              model_attribute(Exchange, :third_price)
            end
          end
        end
      end
    end
  end
end
