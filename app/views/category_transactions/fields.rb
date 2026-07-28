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
        presentation = CategoryColours::Presentation.for(category_transaction&.category)

        div(
          class: "nested-form-wrapper #{'hidden' if category_transaction.marked_for_destruction?}",
          data: { new_record: category_transaction.new_record?, reactive_form_target: "categoryWrapper" }
        ) do
          div(class: "my-1 flex") do
            span(class: "flex items-center text-sm font-medium text-black") do
              div(
                class: "category_container flex min-h-12 items-center justify-center rounded-sm border border-black px-2 py-1 text-sm " \
                       "dark:rounded-md dark:shadow-sm dark:ring-1 dark:ring-slate-950/40",
                style: presentation.inline_style
              ) do
                span(class: "categories_category_name text-nowrap") { category_transaction&.category&.name }

                unless transactable.is_a?(CashTransaction) && (transactable.card_payment? || transactable.card_advance? || transactable.exchange_return?)
                  button(
                    type: :button,
                    class: "ms-2 inline-flex items-center rounded-xs bg-transparent p-1 text-sm text-current " \
                           "hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-current",
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
