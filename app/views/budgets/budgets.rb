# frozen_string_literal: true

class Views::Budgets::Budgets < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

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
        class: "rounded-lg shadow-sm overflow-hidden bg-indigo-950 text-slate-100 my-4 #{'animate-pulse' if tight_budget}",
        data: { id: budget.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-slate-100 text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              link_to budget.description,
                      edit_budget_path(budget),
                      id: "edit_budget_#{budget.id}",
                      class: "truncate text-md underline underline-offset-[3px]",
                      data: { turbo_frame: :center_container }

              span(class: "flex-shrink-0 p-1 rounded-sm bg-white border border-black text-black") do
                from_cent_based_to_float(budget.value, "R$")
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1") do
              span(class: "flex items-center justify-start gap-2 rounded-sm text-slate-100") do
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
            div(class: "flex justify-between gap-2", data: { datatable_target: :category, id: budget.categories.map(&:id) }) do
              budget.categories.each do |category|
                span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1  #{category.bg_colour.sub('bg', 'border')} text-xs") do
                  category.name
                end
              end
            end

            div(class: "flex flex-wrap justify-end gap-2 ml-auto", data: { datatable_target: :entity, id: budget.entities.map(&:id) }) do
              budget.entities.each do |entity|
                div(class: "flex flex-col items-center w-16 text-center text-xs") do
                  image_tag asset_path("avatars/#{entity.avatar_name}"), class: "bg-white size-6 rounded-full mb-1"
                  span(class: "entity_entity_name truncate block max-w-full leading-tight") { entity.entity_name }
                end
              end
            end
          end
        end
      end
    end
  end

  def render_budget(budget)
    tight_budget = budget.remaining_value >= budget.value / 5

    turbo_frame_tag dom_id budget do
      div(
        class: "grid grid-cols-12 border-b border-slate-200 bg-indigo-950 text-slate-100 hover:opacity-80",
        draggable: true,
        data: {
          id: budget.id,
          datatable_target: :row,
          action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop"
        }
      ) do
        div(class: "flex items-center justify-between gap-2 rounded-sm text-slate-100 pl-2") do
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
                  data: { turbo_frame: :center_container }

          span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 opacity-0") do
            pretty_installments(1, 1)
          end
        end

        div(class: "col-span-3 py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: budget.categories.map(&:id) }) do
          budget.categories.each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm #{category.bg_colour} border-1 border-white text-sm") do
              category.name
            end
          end
        end

        div(class: "col-span-2 py-2 flex items-center justify-center flex-wrap gap-2",
            data: { datatable_target: :entity, id: budget.entities.map(&:id) }) do
          budget.budget_entities.order(:entity_id).includes(:entity).each do |budget_entity|
            entity = budget_entity.entity

            div(class: "grid grid-cols-1 text-xs mx-auto") do
              image_tag asset_path("avatars/#{entity.avatar_name}"), class: "bg-white size-5 rounded-full mx-auto"
              span(class: :entity_entity_name) { entity.entity_name }
            end
          end
        end

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto #{'animate-pulse' if tight_budget}") do
          from_cent_based_to_float(budget.remaining_value, "R$")
        end

        div(class: "flex items-center justify-center font-lekton font-bold text-white whitespace-nowrap ml-auto") do
          div(class: "p-1 rounded-md shadow-sm border border-white") do
            from_cent_based_to_float(budget.balance, "R$")
          end
        end
      end
    end
  end
end
