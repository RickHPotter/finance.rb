# frozen_string_literal: true

class Views::Budgets::Budgets < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper
  include ColoursHelper

  attr_reader :mobile, :budgets, :show_rows_not_found

  def initialize(mobile:, budgets:, show_rows_not_found: true)
    @mobile = mobile
    @budgets = budgets
    @show_rows_not_found = show_rows_not_found
  end

  def view_template
    if mobile
      budgets.each do |budget|
        render_mobile_budget(budget)
      end
    elsif budgets.present?
      budgets.each do |budget|
        render_budget(budget)
      end
    elsif show_rows_not_found
      div(class: "text-lg") { I18n.t(:rows_not_found) }
    end
  end

  def render_mobile_budget(budget)
    tight_budget = budget.remaining_value >= budget.value / 5

    turbo_frame_tag dom_id budget do
      div(class: "relative") do
        div(
          class: "absolute -top-2 right-0 p-1 rounded-t-lg bg-yellow-400 shadow-sm border border-yellow-600 font-lekton font-bold
                  text-black text-sm z-40 #{'animate-pulse' if tight_budget}"
        ) do
          from_cent_based_to_float(budget.balance, "R$")
        end
      end

      div(
        class: "rounded-lg shadow-sm overflow-hidden bg-indigo-900 text-zinc-50 my-4 hover:opacity-80 transition-all #{'animate-pulse' if tight_budget}",
        data: { id: budget.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              link_to budget.description,
                      edit_budget_path(budget),
                      id: "edit_budget_#{budget.id}",
                      class: "truncate text-md underline underline-offset-[3px]",
                      data: { turbo_frame: "_top" }

              span(class: "flex-shrink-0 p-1 rounded-sm bg-white border border-black text-black") do
                from_cent_based_to_float(budget.value, "R$")
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1") do
              span(class: "flex items-center justify-start gap-2 rounded-sm") do
                case budget.remaining_value <=> budget.value
                when -1
                  :x_circle
                when 0
                  :warning_octagon
                when 1
                  :check_square
                end => icon

                cached_icon icon
                span(class: "rounded-xs text-xs mr-auto") { I18n.l(budget.date, format: "%B %Y") }
              end
            end

            div(class: "whitespace-nowrap") do
              from_cent_based_to_float(budget.remaining_value, "R$")
            end
          end
          div(class: "flex items-center justify-between gap-2") do
            render_mobile_categories(budget)

            render_mobile_entities(budget)
          end
        end
      end
    end
  end

  def render_budget(budget)
    tight_budget = budget.remaining_value >= budget.value / 5

    turbo_frame_tag dom_id budget do
      div(
        class: "grid grid-cols-12 bg-indigo-900 text-zinc-50 hover:opacity-80 transition-all",
        draggable: true,
        data: {
          id: budget.id,
          datatable_target: :row,
          action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop"
        }
      ) do
        div(class: "flex items-center justify-between gap-2 rounded-sm pl-2") do
          span(class: "size-4", title: pluralise_model(budget, 1)) { cached_icon(:piggy_safe) }

          month, year = I18n.l(budget.date, format: "%B %Y").split
          div(class: "grid grid-cols-1 mr-auto") do
            span(class: "rounded-xs text-xs mr-auto") { month }
            span(class: "rounded-xs text-xs mr-auto") { year }
          end
        end

        div(class: "col-span-4 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2  underline underline-offset-[3px]") do
          link_to "#{pluralise_model(budget, 1).upcase}: #{from_cent_based_to_float(budget.value, 'R$')}",
                  edit_budget_path(budget),
                  id: "edit_budget_#{budget.id}",
                  class: "flex-1 truncate text-md",
                  data: { turbo_frame: "_top" }

          span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 opacity-0") do
            pretty_installments(1, 1)
          end
        end

        render_desktop_categories(budget)

        render_desktop_entities(budget)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto #{'animate-pulse' if tight_budget}") do
          from_cent_based_to_float(budget.remaining_value, "R$")
        end

        div(class: "flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto mr-1") do
          div(class: "p-1 rounded-md shadow-sm border border-white") do
            from_cent_based_to_float(budget.balance, "R$")
          end
        end
      end
    end
  end

  def render_mobile_entities(budget)
    items = budget_entity_popover_items(budget, :id)

    render Views::Entities::Popover.new(
      items:,
      mobile: true,
      target_ids: budget.entities.map(&:id),
      trigger_label: pluralise_model(Entity, items.count),
      variant: :budget
    )
  end

  def render_desktop_entities(budget)
    render Views::Entities::Popover.new(
      items: budget_entity_popover_items(budget, :entity_id),
      mobile: false,
      target_ids: budget.entities.map(&:id),
      trigger_label: "",
      variant: :budget
    )
  end

  def render_mobile_categories(budget)
    render Views::Categories::Popover.new(
      items: budget_category_popover_items(budget),
      mobile: true,
      target_ids: budget.categories.map(&:id),
      trigger_label: pluralise_model(Category, budget.categories.count).upcase,
      variant: :budget
    )
  end

  def render_desktop_categories(budget)
    render Views::Categories::Popover.new(
      items: budget_category_popover_items(budget),
      mobile: false,
      target_ids: budget.categories.map(&:id),
      trigger_label: "",
      variant: :budget
    )
  end

  def budget_entity_popover_items(budget, sort_key)
    budget.budget_entities.sort_by(&sort_key).filter_map do |budget_entity|
      entity = budget_entity.entity
      next if entity.nil?

      {
        name: entity.entity_name,
        avatar_name: entity.avatar_name,
        href: new_cash_transaction_path(cash_transaction: { entity_id: entity.id }),
        data: { turbo_frame: "_top", turbo_prefetch: "false" }
      }
    end
  end

  def budget_category_popover_items(budget)
    budget.budget_categories.sort_by(&:id).filter_map(&:category).map do |category|
      {
        name: category.name,
        style: "background: #{category.hex_colour}; #{auto_text_color(category.hex_colour)}"
      }
    end
  end
end
