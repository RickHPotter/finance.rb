# frozen_string_literal: true

module Views
  module EntityTransactions
    class FieldsSheet < Components::Base # rubocop:disable Metrics/ClassLength
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

        default_bound_type = submitted_bound_type || inferred_bound_type

        SheetContent(
          side: :middle,
          class: "h-[94vh] w-[96vw] max-w-6xl mx-auto rounded-xl border border-slate-300 text-black overflow-hidden flex flex-col",
          data: { controller: "price-mask entity-transaction" }
        ) do
          SheetHeader do
            SheetTitle(class: "entities_entity_name text-black dark:text-white") { entity_transaction&.entity&.entity_name }
            SheetDescription { "" }
          end

          SheetMiddle(class: "min-h-0 flex-1 overflow-y-auto") do
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
                      data: { controller: "input-select",
                              price_mask_target: :input,
                              entity_transaction_target: :priceInput,
                              action: "click->input-select#select input->price-mask#applyMask input->entity-transaction#updatePrice",
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
                      data: { controller: "input-select",
                              price_mask_target: :input,
                              entity_transaction_target: :priceToBeReturnedInput,
                              action: [
                                "click->input-select#select",
                                "input->price-mask#applyMask",
                                "input->entity-transaction#updatePrice",
                                "input->entity-transaction#toggleExchanges"
                              ].join(" "),
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
                                 data: { controller: "input-select",
                                         entity_transaction_target: :exchangesCountInput,
                                         action: "click->input-select#select input->entity-transaction#updateExchangesPrices" }
                  end

                  div(class: "m-auto") do
                    Button(
                      class: modal_icon_button_class,
                      disabled: !entity_transaction.is_payer,
                      data: { entity_transaction_target: :exchangesCountEqualsButton, action: "entity-transaction#copyTransactionInstallmentsCount" }
                    ) do
                      cached_icon(:equals)
                    end
                  end
                end
              end

              div do
                field_id = "entity_transaction_loan_return_percentage_#{form.index}"
                bold_label(form, :loan_return_percentage, field_id)

                div(class: "flex gap-1 justify-between") do
                  div(class: "flex-1") do
                    TextField \
                      form, :loan_return_percentage, type: :number, svg: :number, min: 0, step: "0.0001", id: field_id, class: "font-graduate",
                                                     data: {
                                                       controller: "input-select",
                                                       entity_transaction_target: :loanReturnPercentageInput,
                                                       original_value: entity_transaction.loan_return_percentage,
                                                       action: "click->input-select#select input->entity-transaction#applyLoanReturnPercentage"
                                                     }
                  end

                  Button(
                    type: :button,
                    class: modal_icon_button_class,
                    title: I18n.t("helpers.submit.reset", default: "Reset"),
                    data: { action: "entity-transaction#resetLoanReturnPercentage" }
                  ) do
                    cached_icon(:refresh)
                  end

                  Button(
                    type: :button,
                    class: modal_icon_button_class,
                    title: I18n.t("activerecord.attributes.entity_transaction.loan_return_percentage"),
                    data: { action: "entity-transaction#matchLoanReturnPercentage" }
                  ) do
                    cached_icon(:calculator)
                  end
                end
              end

              if transactable.is_a? CardTransaction
                div do
                  bold_label(form, :bound_type, "entity_transaction_bound_type_#{form.index}")

                  div(class: "flex justify-start gap-1") do
                    label(
                      for: "entity_transaction_standalone_#{form.index}",
                      class: bound_type_label_class
                    ) do
                      radio_button_tag("bound_type_#{form.index}", :standalone,
                                       checked: default_bound_type == :standalone,
                                       id: "entity_transaction_standalone_#{form.index}",
                                       class: "w-4 h-4 text-blue-600 focus:ring-blue-500 cursor-pointer",
                                       data: { entity_transaction_target: :boundType, action: "entity-transaction#fillInBoundType" })

                      span { model_attribute(form.object, :standalone).downcase }
                    end

                    label(
                      for: "entity_transaction_card_bound_#{form.index}",
                      class: bound_type_label_class
                    ) do
                      radio_button_tag("bound_type_#{form.index}", :card_bound,
                                       checked: default_bound_type == :card_bound,
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
              class: "pt-2 grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3 pb-3",
              data: { controller: "nested-form exchange-lock", nested_form_wrapper_selector_value: ".nested-exchange-wrapper" }
            ) do
              template(data_nested_form_target: "template") do
                form.fields_for :exchanges, Exchange.new, child_index: "NEW_NESTED_RECORD" do |exchange_fields|
                  render ::Views::Exchanges::Fields.new(form: exchange_fields, bound_type: default_bound_type)
                end
              end

              exchanges_association =
                (entity_transaction.exchanges.reject(&:marked_for_destruction?).sort_by(&:number) if entity_transaction.exchanges_count.to_i.positive?)

              form.fields_for :exchanges, exchanges_association do |exchange_fields|
                render ::Views::Exchanges::Fields.new(form: exchange_fields, bound_type: default_bound_type)
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
            Button(class: modal_icon_button_class) do
              cached_icon(icon)
            end
          end

          PopoverContent(class: "w-40") do
            Button(variant: :ghost, class: price_helper_button_class,
                   data: { action: "entity-transaction#fillPrice", divider: 1, target: }) do
              model_attribute(Exchange, :full_price)
            end

            Button(variant: :ghost, class: price_helper_button_class,
                   data: { action: "entity-transaction#fillPrice", divider: 2, target: }) do
              model_attribute(Exchange, :half_price)
            end

            Button(variant: :ghost, class: price_helper_button_class,
                   data: { action: "entity-transaction#fillPrice", divider: 3, target: }) do
              model_attribute(Exchange, :third_price)
            end
          end
        end
      end

      private

      def modal_icon_button_class
        "rounded-sm border border-transparent bg-gray-100 text-black hover:bg-gray-200 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-300 " \
          "dark:hover:bg-slate-700 dark:hover:text-slate-100"
      end

      def price_helper_button_class
        "w-full justify-start pl-2 text-black hover:text-black dark:text-slate-100 dark:hover:bg-slate-800 dark:hover:text-white"
      end

      def bound_type_label_class
        "flex items-center gap-2 px-3 py-2 border rounded-md cursor-pointer select-none transition-all duration-200 text-sm font-medium " \
          "border-gray-300 bg-white text-gray-700 hover:border-blue-400 hover:bg-blue-50 has-checked:border-blue-600 has-checked:bg-blue-100 " \
          "has-checked:text-blue-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300 dark:hover:border-sky-500/60 " \
          "dark:hover:bg-slate-800 dark:hover:text-slate-100 dark:has-checked:border-sky-500 dark:has-checked:bg-sky-500/15 " \
          "dark:has-checked:text-sky-200"
      end

      def rails_view_context
        context[:rails_view_context]
      end

      def params
        rails_view_context.params
      end

      def submitted_bound_type
        rails_view_context.params["bound_type_#{form.index}"]&.presence_in(%w[standalone card_bound])&.to_sym
      end

      def inferred_bound_type
        if entity_transaction.exchanges_count.to_i.zero? || entity_transaction.exchanges.first&.standalone?
          :standalone
        else
          :card_bound
        end
      end
    end
  end
end
