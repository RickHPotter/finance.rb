# frozen_string_literal: true

class Views::Lalas::CashInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo
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
        cash_transaction = cash_installment.cash_transaction.reload
        style = solid_or_gradient_style(cash_transaction.category_transactions.order(:id).map(&:category))

        render_mobile_cash_installment(cash_installment, cash_transaction, style)
      end
    else
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction.reload
        style = solid_or_gradient_style(cash_transaction.category_transactions.order(:id).map(&:category))

        render_cash_installment(cash_installment, cash_transaction, style)
      end
    end
  end

  def render_mobile_cash_installment(cash_installment, cash_transaction, style)
    turbo_frame_tag dom_id cash_installment do
      icon = choose_icon(cash_installment)

      div(
        class: "rounded-lg shadow-sm overflow-hidden my-4 border-2",
        style: "background-clip: padding-box; #{style}",
        data: { id: cash_installment.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              span(class: "truncate text-md underline underline-offset-[3px]") do
                cash_transaction.description
              end

              span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0 #{'opacity-40' if cash_transaction.cash_installments_count == 1}") do
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
              border = style.split("; color:").last
              cash_transaction.category_transactions.order(:id).map(&:category).each do |category|
                span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 text-xs", style: "border-color: #{border}") do
                  category.name
                end
              end
            end

            render_mobile_entities(cash_transaction)
          end
        end
      end
    end
  end

  def render_cash_installment(cash_installment, cash_transaction, style)
    turbo_frame_tag dom_id cash_installment do
      icon = choose_icon(cash_installment)

      div(
        class: "grid grid-cols-12 hover:opacity-80",
        style: "background-clip: padding-box; #{style}",
        draggable: true,
        data: { id: cash_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "col-span-5 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
          date, time = I18n.l(cash_installment.date, format: :shorter).split(",")
          div(class: "grid grid-cols-1") do
            span(class: "rounded-xs text-xs mr-auto") { date }
            span(class: "rounded-xs text-xs mr-auto") { time }
          end

          span(id: "edit_cash_transaction_#{cash_transaction.id}", class: "flex-1 truncate text-md underline underline-offset-[3px]") do
            cash_transaction.description
          end

          span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0 #{'opacity-40' if cash_installment.cash_installments_count == 1}") do
            pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
          end
        end

        div(class: "col-span-3 py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
          border = style.split("; color:").last
          cash_transaction.category_transactions.order(:id).map(&:category).each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 text-sm", style: "border-color: #{border}") do
              category.name
            end
          end
        end

        render_desktop_entities(cash_transaction)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(cash_installment.price, "R$")
        end

        div(class: "py-2 px-2 font-lekton font-bold whitespace-nowrap ml-auto") do
          span(class: "flex items-center justify-center gap-2 hover:bg-white hover:text-money hover:rounded-sm hover:scale-160") do
            cached_icon(icon)
            span { cash_installment.paid ? "Sim" : "Não" }
          end
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

  def render_mobile_entities(cash_transaction)
    items = entity_popover_items(cash_transaction, :id)

    render Views::Entities::Popover.new(
      items:,
      mobile: true,
      target_ids: cash_transaction.entities.map(&:id),
      trigger_label: pluralise_model(Entity, items.count).upcase,
      variant: :cash
    )
  end

  def render_desktop_entities(cash_transaction)
    render Views::Entities::Popover.new(
      items: entity_popover_items(cash_transaction, :entity_id),
      mobile: false,
      target_ids: cash_transaction.entities.map(&:id),
      trigger_label: "",
      variant: :cash
    )
  end

  def entities_for(cash_transaction, sort_key)
    cash_transaction.entity_transactions.sort_by(&sort_key).filter_map(&:entity)
  end

  def entity_popover_items(cash_transaction, sort_key)
    entities_for(cash_transaction, sort_key).map do |entity|
      {
        name: entity.entity_name,
        avatar_name: entity.avatar_name
      }
    end
  end
end
