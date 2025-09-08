# frozen_string_literal: true

class Views::Lalas::CashInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper
  include CacheHelper
  include ColoursHelper

  attr_reader :mobile, :cash_installments

  def initialize(mobile:, cash_installments:)
    @mobile = mobile
    @cash_installments = cash_installments
  end

  def view_template
    if mobile
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction
        style = solid_or_gradient_style(cash_transaction.category_transactions.order(:id).map(&:category))

        render_mobile_cash_installment(cash_installment, cash_transaction, style)
      end
    else
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction
        style = solid_or_gradient_style(cash_transaction.category_transactions.order(:id).map(&:category))

        render_cash_installment(cash_installment, cash_transaction, style)
      end
    end
  end

  def render_mobile_cash_installment(cash_installment, cash_transaction, style)
    turbo_frame_tag dom_id cash_installment do
      icon = choose_icon(cash_installment)

      div(
        class: "rounded-lg shadow-sm overflow-hidden my-4",
        style: "background-clip: padding-box; #{style}",
        data: { id: cash_installment.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-black text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0 underline underline-offset-[3px]") do
              span(class: "truncate text-md") do
                cash_transaction.description
              end

              span(class: "flex-shrink p-1 rounded-sm bg-white border border-black #{'opacity-40' if cash_transaction.cash_installments_count == 1}") do
                pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1 flex items-center") do
              button(class: "hover:bg-white hover:text-money hover:rounded-full hover:scale-160 transition-all duration-200") do
                cached_icon(icon)
              end

              span(class: "whitespace-nowrap pl-2") do
                format = cash_transaction.investment? ? "%B %Y" : :short
                I18n.l(cash_installment.date, format:)
              end
            end

            div(class: "whitespace-nowrap") do
              from_cent_based_to_float(cash_installment.price, "R$")
            end
          end

          div(class: "flex flex-wrap items-center gap-1") do
            div(class: "flex flex-wrap gap-1", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
              cash_transaction.category_transactions.order(:id).map(&:category).each do |category|
                span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-xs") do
                  category.name
                end
              end
            end

            div(class: "flex flex-wrap justify-end gap-2 ml-auto", data: { datatable_target: :entity, id: cash_transaction.entities.map(&:id) }) do
              cash_transaction.entity_transactions.order(:id).map(&:entity).each do |entity|
                span(class: "flex flex-col items-center w-16 text-center text-xs") do
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

  def render_cash_installment(cash_installment, cash_transaction, style)
    turbo_frame_tag dom_id cash_installment do
      icon = choose_icon(cash_installment)

      div(
        class: "grid grid-cols-8 border-b border-slate-200 hover:opacity-80",
        style: "background-clip: padding-box; #{style}",
        draggable: true,
        data: { id: cash_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "flex items-center justify-between gap-2 rounded-sm text-slate-900 pl-2") do
          date, time = I18n.l(cash_installment.date, format: :shorter).split(",")
          div(class: "grid grid-cols-1") do
            span(class: "rounded-xs text-slate-900 text-xs mr-auto") { date }
            span(class: "rounded-xs text-slate-900 text-xs mr-auto") { time }
          end
        end

        div(class: "col-span-3 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2  underline underline-offset-[3px]") do
          span(class: " flex-1 truncate text-md") do
            cash_transaction.description
          end

          span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 #{'opacity-40' if cash_installment.cash_installments_count == 1}") do
            pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
          end
        end

        div(class: "py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
          cash_transaction.category_transactions.order(:id).map(&:category).each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
              category.name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center flex-wrap gap-2",
            data: { datatable_target: :entity, id: cash_transaction.entities.map(&:id) }) do
          cash_transaction.entity_transactions.order(:entity_id).includes(:entity).each do |entity_transaction|
            entity = entity_transaction.entity

            span(class: "flex-1 grid grid-cols-1 text-xs mx-auto") do
              image_tag asset_path("avatars/#{entity.avatar_name}"), class: "bg-white size-5 rounded-full mx-auto"
              span(class: :entity_entity_name) { entity.entity_name }
            end
          end
        end

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(cash_installment.price, "R$")
        end

        div(class: "py-2 px-2 flex items-center justify-center gap-2 font-lekton font-bold whitespace-nowrap ml-auto") do
          span(class: "hover:bg-white hover:text-money hover:rounded-sm hover:scale-160") do
            cached_icon(icon)
          end
          span { cash_installment.paid ? "Sim" : "Não" }
        end
      end
    end
  end

  def choose_icon(cash_installment)
    case [ cash_installment.paid, cash_installment.date > Time.zone.today ]
    in [ true,  _     ] then :check_square
    in [ false, true  ] then :warning_octagon
    in [ false, false ] then :x_circle
    end
  end
end
