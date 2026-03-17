# frozen_string_literal: true

class Views::Lalas::CardInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include CacheHelper
  include ColoursHelper

  attr_reader :mobile, :card_installments, :user_card_id

  def initialize(mobile:, card_installments:, user_card_id:)
    @mobile = mobile
    @card_installments = card_installments
    @user_card_id = user_card_id
  end

  def view_template
    if mobile
      card_installments.each do |card_installment|
        card_transaction = card_installment.card_transaction
        style = solid_or_gradient_style(card_transaction.category_transactions.order(:id).map(&:category))

        render_mobile_card_installment(card_installment, card_transaction, style)
      end
    else
      card_installments.each do |card_installment|
        card_transaction = card_installment.card_transaction
        style = solid_or_gradient_style(card_transaction.category_transactions.order(:id).map(&:category))

        render_card_installment(card_installment, card_transaction, style)
      end
    end
  end

  def render_mobile_card_installment(card_installment, card_transaction, style)
    turbo_frame_tag dom_id card_installment do
      div(
        class: "rounded-lg shadow-sm overflow-hidden my-4 border-2",
        style: "background-clip: padding-box; #{style}",
        data: { id: card_installment.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              span(class: "truncate text-md underline underline-offset-[3px]") do
                card_transaction.description
              end

              span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
                pretty_installments(card_installment.number, card_installment.card_installments_count)
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            span(class: "text-xs text-start flex-1") { I18n.l(card_installment.date, format: :short) }

            div(class: "whitespace-nowrap") do
              from_cent_based_to_float(card_installment.price, "R$")
            end
          end

          div(class: "flex flex-wrap items-center gap-1") do
            div(class: "flex flex-wrap gap-1", data: { datatable_target: :category, id: card_transaction.categories.map(&:id) }) do
              card_transaction.category_transactions.order(:id).map(&:category).each do |category|
                span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-xs") do
                  category.name
                end
              end
            end

            render_mobile_entities(card_transaction)
          end
        end
      end
    end
  end

  def render_card_installment(card_installment, card_transaction, style)
    turbo_frame_tag dom_id card_installment do
      div(
        class: "grid grid-cols-11 hover:opacity-80",
        style: "background-clip: padding-box; #{style}",
        draggable: true,
        data: { id: card_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "col-span-5 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
          date, time = I18n.l(card_installment.date, format: :shorter).split(",")
          div(class: "grid grid-cols-1") do
            span(class: "rounded-xs text-xs mr-auto") { date }
            span(class: "rounded-xs text-xs mr-auto") { time }
          end

          span(id: "edit_card_transaction_#{card_transaction.id}", class: "flex-1 truncate text-md underline underline-offset-[3px]") do
            card_transaction.description
          end

          span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
            pretty_installments(card_installment.number, card_installment.card_installments_count)
          end
        end

        div(
          class: "col-span-3 py-2 flex items-center justify-center gap-2",
          data: { datatable_target: :category, id: card_transaction.categories.map(&:id) }
        ) do
          if card_transaction.categories.count > 1
            first_one = card_transaction.categories.first
            remaining = card_transaction.categories[1..]

            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
              first_one.name
            end

            Popover(options: { placement: "right" }, class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
              PopoverTrigger(class: "w-full") do
                button(class: "text-xs") do
                  "+#{card_transaction.categories.count - 1}"
                end
              end

              PopoverContent(class: "z-50 !opacity-100 ml-2") do
                remaining.each do |category|
                  span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
                    category.name
                  end
                end
              end
            end
          else
            card_transaction.category_transactions.order(:id).map(&:category).each do |category|
              span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
                category.name
              end
            end
          end
        end

        render_desktop_entities(card_transaction)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto mr-1") do
          from_cent_based_to_float(card_installment.price, "R$")
        end
      end
    end
  end

  def render_mobile_entities(card_transaction)
    items = entity_popover_items(card_transaction, :id)

    render Views::Entities::Popover.new(
      items:,
      mobile: true,
      target_ids: card_transaction.entities.map(&:id),
      trigger_label: pluralise_model(Entity, items.count).upcase,
      variant: :card
    )
  end

  def render_desktop_entities(card_transaction)
    render Views::Entities::Popover.new(
      items: entity_popover_items(card_transaction, :id),
      mobile: false,
      target_ids: card_transaction.entities.map(&:id),
      trigger_label: "",
      variant: :card
    )
  end

  def entity_popover_items(card_transaction, sort_key)
    card_transaction.entity_transactions.order(:id).includes(:entity).sort_by(&sort_key).map do |entity_transaction|
      entity = entity_transaction.entity

      {
        name: entity.entity_name,
        avatar_name: entity.avatar_name,
        info_class: "entity_exchanges_info text-[10px] leading-tight text-zinc-500",
        info_text: entity_exchanges_info(entity_transaction)
      }
    end
  end

  def entity_exchanges_info(entity_transaction)
    info = ""
    info += "[#{from_cent_based_to_float(entity_transaction.price_to_be_returned, 'R$')}]" if entity_transaction.exchanges_count.positive?
    info += " (#{entity_transaction.exchanges_count})" if entity_transaction.exchanges_count > 1
    info
  end
end
