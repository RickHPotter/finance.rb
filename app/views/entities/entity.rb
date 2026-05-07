# frozen_string_literal: true

class Views::Entities::Entity < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::Cycle

  include CacheHelper
  include TranslateHelper

  attr_reader :entity, :mobile

  def initialize(entity:, mobile: false)
    @entity = entity
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(entity) do
      mobile ? mobile_row : desktop_row
    end
  end

  private

  def desktop_row
    div(
      class: "grid grid-cols-9 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: entity.id, datatable_target: :row }
    ) do
      div(class: "px-2 py-3 flex items-center justify-center") { image_tag asset_path("avatars/#{entity.avatar_name}"), class: "size-7 rounded-full" }
      div(class: "col-span-2 px-2 py-3 text-center font-lekton font-semibold") do
        link_to entity_path(entity),
                id: "show_entity_#{entity.id}",
                class: "px-4 whitespace-nowrap hover:underline",
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          entity.name
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 text-sm font-semibold text-slate-700") do
        status_badge
      end

      div(class: "jump_to_card_transactions px-2 py-3 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if entity.card_transactions_count.positive?
          link_to(
            entity.card_transactions_count,
            search_card_transactions_path(card_transaction: { entity_id: entity.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { entity.card_transactions_count }
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(entity.card_transactions_total, "R$")
        end
      end

      div(class: "jump_to_cash_transactions px-2 py-3 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if entity.cash_transactions_count.positive?
          link_to(
            entity.cash_transactions_count,
            cash_transactions_path(cash_transaction: { entity_id: entity.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { entity.cash_transactions_count }
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(entity.cash_transactions_total, "R$")
        end
      end

      div(class: "flex items-center justify-center px-2 py-3") do
        div(class: "flex items-center justify-end gap-1") do
          link_to(edit_entity_path(entity), id: "edit_entity_#{entity.id}",
                                            class: action_button_class,
                                            title: action_message(:edit),
                                            aria: { label: action_message(:edit) },
                                            data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:pencil) }

          unless entity.built_in?
            LinkWithConfirmation(
              id: entity.id,
              icon: :destroy,
              link_params: {
                href: entity_path(entity),
                size: :xs,
                id: "delete_entity_#{entity.id}",
                class: destructive_action_button_class,
                data: { turbo_method: :delete }
              }
            )
          end
        end
      end
    end
  end

  def mobile_row
    div(class: "rounded-lg shadow-sm overflow-hidden my-3 bg-slate-100", data: { id: entity.id, datatable_target: :row }) do
      div(class: "p-4 bg-linear-to-r from-slate-700 via-slate-400 to-white") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            image_tag asset_path("avatars/#{entity.avatar_name}"), class: "w-6 h-6 rounded-full"
            link_to(entity.name, entity_path(entity), id: "show_entity_#{entity.id}",
                                                      class: "text-lg font-semibold text-black underline underline-offset-[3px]",
                                                      data: { turbo_frame: "_top", turbo_prefetch: false })
          end

          status_badge
        end
      end

      div(class: "p-4") do
        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center text-sm font-medium text-slate-500") do
              cached_icon :number
              span(class: "ml-2") { pluralise_model(CardTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { entity.card_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CardTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(entity.card_transactions_total, "R$") }
              link_to(search_card_transactions_path(card_transaction: { entity_id: entity.id }, all_month_years: true),
                      class: "my-auto -mt-4", data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:jump_to) }
            end
          end
        end

        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center text-sm font-medium text-slate-500") do
              cached_icon :number
              span(class: "ml-2 truncate") { pluralise_model(CashTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { entity.cash_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CashTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(entity.cash_transactions_total, "R$") }
              link_to(cash_transactions_path(cash_transaction: { entity_id: entity.id }, all_month_years: true),
                      class: "my-auto -mt-4", data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:jump_to) }
            end
          end
        end
      end
    end
  end

  def action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-sky-200 bg-sky-50 text-sky-700 " \
      "shadow-sm transition hover:border-sky-600 hover:bg-sky-600 hover:text-white [&_svg]:size-4"
  end

  def destructive_action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-red-200 bg-white text-red-700 " \
      "shadow-sm transition hover:border-red-600 hover:bg-red-600 hover:text-white [&_svg]:size-4 [&_svg]:!text-current"
  end

  def status_badge
    colour = entity.active? ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-700"

    span(class: "rounded-full px-2.5 py-1 text-xs font-semibold uppercase tracking-wide #{colour}") do
      model_attribute(Entity, "statuses.#{entity.active? ? :active : :inactive}")
    end
  end
end
