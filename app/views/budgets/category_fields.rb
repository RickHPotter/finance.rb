# frozen_string_literal: true

class Views::Budgets::CategoryFields < Views::Base
  attr_accessor :form

  def initialize(form:)
    @form = form
  end

  def view_template
    budget_category = form.object
    budget_category_colour = budget_category&.category&.bg_colour

    div(class: "nested-form-wrapper", data: { new_record: budget_category.new_record?, reactive_form_target: "categoryWrapper" }) do
      div(class: "flex w-full my-1") do
        span(class: "flex items-center text-sm font-medium text-black") do
          div(class: "category_container flex items-center justify-center px-2 py-1 rounded-sm border-1 border-black text-sm #{budget_category_colour}") do
            span(class: "categories_category_name text-nowrap", data: { dynamic_description_target: :category }) do
              budget_category&.category&.name
            end

            button(
              type: :button,
              class: "inline-flex items-center p-1 ms-2 text-sm text-black bg-transparent rounded-xs hover:bg-gray-800 hover:text-gray-200",
              aria_label: "Remove",
              data: { action: "reactive-form#removeCategory dynamic-description#updateDescription" }
            ) do
              svg(
                class: "w-2 h-2 pointer-events-none",
                aria_hidden: "true",
                xmlns: "http://www.w3.org/2000/svg",
                fill: "none",
                viewbox: "0 0 14 14"
              ) do |s|
                s.path(
                  stroke: "currentColor",
                  stroke_linecap: "round",
                  stroke_linejoin: "round",
                  stroke_width: "2",
                  d: "m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"
                )
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
