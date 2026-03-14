# frozen_string_literal: true

class Views::CardInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper
  include ColoursHelper

  attr_reader :mobile, :card_installments, :user_card_id, :entity_links

  def initialize(mobile:, card_installments:, user_card_id:, entity_links: true)
    @mobile = mobile
    @card_installments = card_installments
    @user_card_id = user_card_id
    @entity_links = entity_links
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
        class: "rounded-lg shadow-sm overflow-hidden my-2",
        style: "background-clip: padding-box; #{style}",
        data: { id: card_installment.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              if user_card_id.nil?
                link_to card_transaction.user_card.user_card_name,
                        card_transactions_path(user_card_id: card_transaction.user_card_id, format: :turbo_stream),
                        class: "px-2 py-1 flex items-center justify-center rounded-sm bg-blue-800 border-1 border-slate-200 text-slate-200",
                        data: { turbo_frame: :center_container, turbo_prefetch: false }
              end

              link_to card_transaction.description, edit_card_transaction_path(card_transaction),
                      id: "edit_card_transaction_#{card_transaction.id}",
                      class: "truncate text-md underline underline-offset-[3px]",
                      data: { turbo_frame: :center_container }

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
            render_mobile_categories(card_transaction)

            render_mobile_entities(card_transaction)
          end
        end
      end
    end
  end

  def render_card_installment(card_installment, card_transaction, style)
    turbo_frame_tag dom_id card_installment do
      div(
        class: "grid grid-cols-12 hover:opacity-80 transition-all",
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

          if user_card_id.nil?
            link_to card_transaction.user_card.user_card_name,
                    card_transactions_path(user_card_id: card_transaction.user_card_id, format: :turbo_stream),
                    class: "px-2 py-1 ml-2 flex-1 items-center justify-center rounded-sm bg-blue-800 border-1 border-slate-200 text-slate-200",
                    data: { turbo_frame: :center_container, turbo_prefetch: false }
          end

          link_to card_transaction.description, edit_card_transaction_path(card_transaction),
                  id: "edit_card_transaction_#{card_transaction.id}",
                  class: "flex-5 truncate text-md underline underline-offset-[3px]",
                  data: { turbo_frame: :center_container }

          span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
            pretty_installments(card_installment.number, card_installment.card_installments_count)
          end
        end

        render_desktop_categories(card_transaction)

        render_desktop_entities(card_transaction)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(card_installment.price, "R$")
        end

        div(class: "py-2 flex items-center justify-center") do
          div(class: "flex items-center justify-center px-2 ml-auto rounded-md") do
            link_to(
              duplicate_card_transaction_path(card_transaction),
              class: "p-1 bg-slate-200 border border-slate-200 text-black",
              data: { turbo_frame: :center_container }
            ) do
              cached_icon :copy
            end

            LinkWithConfirmation(
              id: card_transaction.id,
              icon: :destroy,
              link_params: {
                href: card_transaction_path(card_transaction, card_installment_id: card_installment.id),
                size: :xs,
                id: "delete_card_transaction_#{card_transaction.id}",
                class: "text-red-600 hover:text-red-800 mx-2 bg-white rounded-4xl",
                data: { turbo_method: :delete }
              }
            )
          end
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

  def render_mobile_categories(card_transaction)
    render Views::Categories::Popover.new(
      items: card_category_popover_items(card_transaction),
      mobile: true,
      target_ids: card_transaction.categories.map(&:id),
      trigger_label: pluralise_model(Category, card_transaction.categories.count).upcase,
      variant: :card
    )
  end

  def render_desktop_categories(card_transaction)
    render Views::Categories::Popover.new(
      items: card_category_popover_items(card_transaction),
      mobile: false,
      target_ids: card_transaction.categories.map(&:id),
      trigger_label: "",
      variant: :card
    )
  end

  def entity_popover_items(card_transaction, sort_key)
    card_transaction.entity_transactions.order(:id).includes(:entity).sort_by(&sort_key).map do |entity_transaction|
      entity = entity_transaction.entity
      href = entity_links ? new_card_transaction_path(user_card_id:, card_transaction: { entity_id: entity.id }, format: :turbo_stream) : nil

      {
        name: entity.entity_name,
        avatar_name: entity.avatar_name,
        href:,
        data: { turbo_frame: "center_container", turbo_prefetch: "false" },
        info_class: "hidden entity_exchanges_info",
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

  def card_category_popover_items(card_transaction)
    card_transaction.category_transactions.sort_by(&:id).filter_map(&:category).map do |category|
      {
        name: category.name,
        style: "border-color: black"
      }
    end
  end
end
