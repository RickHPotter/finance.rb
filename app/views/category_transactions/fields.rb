# frozen_string_literal: true

module Views
  module CategoryTransactions
    class Fields < Components::Base
      include Phlex::Rails::Helpers::ImageTag
      include Phlex::Rails::Helpers::AssetPath

      include CacheHelper

      attr_reader :form, :transactable, :category_transaction

      def initialize(form:)
        @form = form
        @transactable = form.options[:parent_builder].object
        @category_transaction = form.object
      end

      def view_template
        colour = category_transaction&.category&.bg_colour

        div(class: "nested-form-wrapper", data: { new_record: category_transaction.new_record?, reactive_form_target: "categoryWrapper" }) do
          div(class: "flex my-1") do
            span(class: "flex items-center text-sm font-medium text-black") do
              div(class: "category_container flex items-center justify-center px-2 py-1 rounded-sm border-1 border-black text-sm #{colour}") do
                span(class: "categories_category_name text-nowrap") { category_transaction&.category&.name }

                unless transactable.is_a?(CashTransaction) && transactable.exchange_return?
                  button(
                    type: :button,
                    class: "inline-flex items-center p-1 ms-2 text-sm text-black bg-transparent rounded-xs hover:bg-gray-800 hover:text-gray-200",
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
          form.hidden_field :_destroy
        end
      end
    end
  end
end
