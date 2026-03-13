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
      class: "grid grid-cols-8 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: entity.id, datatable_target: :row }
    ) do
      div(class: "px-1 flex items-center justify-center") { image_tag asset_path("avatars/#{entity.avatar_name}"), class: "size-7 rounded-full" }
      div(class: "col-span-2 px-1 text-center font-lekton font-semibold") { span(class: "px-4 whitespace-nowrap") { entity.entity_name } }

      div(class: "jump_to_card_transactions px-1 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if entity.card_transactions_count.positive?
          link_to(
            entity.card_transactions_count,
            search_card_transactions_path(card_transaction: { entity_id: entity.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: :_top, turbo_prefetch: false }
          )
        else
          span { entity.card_transactions_count }
        end
      end

      div(class: "flex items-center justify-center font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(entity.card_transactions_total, "R$")
        end
      end

      div(class: "jump_to_cash_transactions px-1 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if entity.cash_transactions_count.positive?
          link_to(
            entity.cash_transactions_count,
            cash_transactions_path(cash_transaction: { entity_id: entity.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: :_top, turbo_prefetch: false }
          )
        else
          span { entity.cash_transactions_count }
        end
      end

      div(class: "flex items-center justify-center font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(entity.cash_transactions_total, "R$")
        end
      end

      div(class: "flex items-center justify-center") do
        div(class: "flex items-center justify-center px-2 my-1 rounded-md") do
          link_to(edit_entity_path(entity), id: "edit_entity_#{entity.id}",
                                            class: "text-blue-600 hover:text-blue-800 mx-2 bg-sky-200 rounded-4xl",
                                            data: { turbo_frame: :_top }) { cached_icon(:pencil) }

          link_to(entity_path(entity), id: "delete_entity_#{entity.id}",
                                       class: "text-red-600 hover:text-red-800 mx-2 bg-rose-200 rounded-4xl",
                                       data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }) { cached_icon(:destroy) }
        end
      end
    end
  end

  def mobile_row
    div(class: "rounded-lg shadow-sm overflow-hidden my-3 bg-slate-100", data: { id: entity.id, datatable_target: :row }) do
      div(class: "p-4 bg-gradient-to-r from-slate-700 via-slate-400 to-white") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            image_tag asset_path("avatars/#{entity.avatar_name}"), class: "w-6 h-6 rounded-full"
            link_to(entity.entity_name, edit_entity_path(entity), id: "edit_entity_#{entity.id}",
                                                                  class: "text-lg font-semibold text-black underline underline-offset-[3px]",
                                                                  data: { turbo_frame: :_top })
          end
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
                      class: "my-auto mt-[-1rem]", data: { turbo_frame: :_top, turbo_prefetch: false }) { cached_icon(:jump_to) }
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
                      class: "my-auto mt-[-1rem]", data: { turbo_frame: :_top, turbo_prefetch: false }) { cached_icon(:jump_to) }
            end
          end
        end
      end
    end
  end
end
