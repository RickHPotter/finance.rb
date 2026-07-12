# frozen_string_literal: true

module Views
  module CategoryTransactions
    class Fields < Components::Base
      include CacheHelper

      attr_reader :form, :transactable, :category_transaction

      def initialize(form:)
        @form = form
        @transactable = form.options[:parent_builder].object
        @category_transaction = form.object
      end

      def view_template
        colour = category_transaction&.category&.hex_colour

        div(
          class: "nested-form-wrapper #{'hidden' if category_transaction.marked_for_destruction?}",
          data: { new_record: category_transaction.new_record?, reactive_form_target: "categoryWrapper" }
        ) do
          div(class: "my-1 flex") do
            span(class: "flex items-center text-sm font-medium text-black") do
              div(
                class: "category_container flex min-h-12 items-center justify-center rounded-sm border border-black px-2 py-1 text-sm " \
                       "text-black dark:rounded-md dark:border-slate-700 dark:text-black dark:shadow-sm dark:ring-1 dark:ring-slate-950/40",
                style: "background: #{colour}"
              ) do
                span(class: "categories_category_name text-nowrap") { category_transaction&.category&.name }

                unless transactable.is_a?(CashTransaction) && (transactable.card_payment? || transactable.card_advance? || transactable.exchange_return?)
                  button(
                    type: :button,
                    class: "ms-2 inline-flex items-center rounded-xs bg-transparent p-1 text-sm text-black hover:bg-gray-800 hover:text-gray-200 " \
                           "dark:text-slate-950 dark:hover:bg-slate-950/40 dark:hover:text-slate-100",
                    aria_label: "Remove",
                    data: { action: "click->reactive-form#removeCategory" }
                  ) do
                    cached_icon(:little_x)
                  end
                end
              end
            end
          end

          form.hidden_field :category_id, class: :categories_category_id
          form.hidden_field :id if category_transaction.persisted?
          form.hidden_field :_destroy
        end
      end
    end
  end
end
