# frozen_string_literal: true

class Views::Budgets::Budgets < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper

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
      div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
    end
  end

  def render_mobile_budget(budget)
    turbo_frame_tag dom_id budget do
      div(class: "rounded-lg shadow-sm overflow-hidden bg-indigo-950 text-slate-100 my-2", data: { id: budget.id, datatable_target: :row }) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-slate-100 text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              link_to "#{pluralise_model(budget, 1)}: #{budget.description}",
                      edit_budget_path(budget),
                      id: "edit_budget_#{budget.id}",
                      class: "truncate text-md underline underline-offset-[3px]",
                      data: { turbo_frame: :center_container }

              span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0") do
                from_cent_based_to_float(budget.value, "R$")
              end
            end
          end
          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1") do
              span(class: "flex items-center justify-start gap-2 rounded-sm text-slate-100 mx-auto") do
                case budget.remaining_value <=> budget.value
                when -1
                  :x_circle
                when 0
                  :warning_octagon
                when 1
                  :check_square
                end => icon

                render_icon icon
                I18n.l(DateTime.new(budget.year, budget.month, 1).end_of_month, format: :shorter)
              end
            end
            div(class: "whitespace-nowrap") do
              from_cent_based_to_float(budget.remaining_value, "R$")
            end
          end
          div(class: "flex items-center justify-between gap-2") do
            div(class: "flex justify-between gap-2", data: { datatable_target: :category, id: budget.categories.map(&:id) }) do
              budget.categories.each do |category|
                span(class: "py-1 rounded-full text-xs font-medium underline underline-offset-[3px]") do
                  category.category_name
                end
              end
            end
            div(class: "flex justify-between gap-2", data: { datatable_target: :entity, id: budget.entities.map(&:id) }) do
              budget.entities.each do |entity|
                span(class: "px-2 py-1 rounded-full text-xs font-medium bg-purple-100 border border-1 border-gray-500") do
                  entity.entity_name
                end
              end
            end
          end
        end
      end

      div(class: "p-1 font-lekton font-bold whitespace-nowrap text-right") do
        from_cent_based_to_float(budget.balance, "R$")
      end
    end
  end

  def render_budget(budget)
    tight_budget = budget.remaining_value >= budget.value / 5

    turbo_frame_tag dom_id budget do
      div(
        class: "grid grid-cols-8 border-b border-slate-200 bg-indigo-950 text-slate-100 hover:opacity-80",
        draggable: true,
        data: {
          id: budget.id,
          datatable_target: :row,
          action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop"
        }
      ) do
        div(class: "flex items-center justify-between gap-2 rounded-sm text-slate-100 mx-auto") do
          span(title: pluralise_model(budget, 1)) { render_icon(:safe) }
          span { I18n.l(DateTime.new(budget.year, budget.month, 1).end_of_month, format: :shorter) }
        end

        div(class: "col-span-3 flex items-center justify-center gap-1 mx-2 underline") do
          link_to "#{from_cent_based_to_float(budget.value, 'R$')} - #{budget.description}",
                  edit_budget_path(budget),
                  id: "edit_budget_#{budget.id}",
                  class: "truncate text-md",
                  data: { turbo_frame: :center_container }
        end

        div(class: "py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: budget.categories.map(&:id) }) do
          budget.categories.each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm #{category.bg_colour} border-1 border-white text-sm") do
              category.category_name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center flex-wrap gap-2", data: { datatable_target: :entity, id: budget.entities.map(&:id) }) do
          budget.entities.each do |entity|
            span(class: "px-4 rounded-full text-sm bg-purple-100 text-black border-1 border-white") do
              entity.entity_name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto #{'animate-pulse' if tight_budget}") do
          from_cent_based_to_float(budget.remaining_value, "R$")
        end

        div(class: "py-2 px-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(budget.balance, "R$")
        end
      end
    end
  end
end
