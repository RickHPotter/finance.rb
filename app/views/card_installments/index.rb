# frozen_string_literal: true

class Views::CardInstallments::Index < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

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
        class: "rounded-lg shadow-sm overflow-hidden my-2 hover:opacity-80 transition-all",
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
        class: "grid grid-cols-12 hover:opacity-80 transition-all",
        style: "background-clip: padding-box; #{style}",
        draggable: true,
        data: { id: card_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "col-span-5 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2 hover:opacity-65") do
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

        div(
          class: "col-span-3 py-2 flex items-center justify-center gap-2 hover:opacity-65",
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

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto hover:opacity-65") do
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
    entity_transactions = card_transaction.entity_transactions.order(:id).includes(:entity)

    div(class: "flex flex-wrap justify-end gap-2 ml-auto", data: { datatable_target: :entity, id: card_transaction.entities.map(&:id) }) do
      if entity_transactions.one?
        entity_transactions.each do |entity_transaction|
          render_entity_link(entity_transaction,
                             wrapper_class: "flex flex-col items-center w-16 text-center text-inherit",
                             avatar_class: "size-6 mb-1",
                             name_class: "entity_entity_name truncate block max-w-full leading-tight",
                             info_class: "hidden entity_exchanges_info")
        end
      else
        details(class: "ml-auto w-full") do
          summary(class: "list-none flex items-center justify-end gap-2 cursor-pointer") do
            render_entity_avatar_stack(entity_transactions, avatar_class: "size-6", limit: 3)
            span(class: "text-xs underline underline-offset-[3px] whitespace-nowrap") { pluralise_model(Entity, entity_transactions.count) }
          end

          div(class: "mt-2 flex flex-wrap justify-end gap-2") do
            entity_transactions.each do |entity_transaction|
              render_entity_link(entity_transaction,
                                 wrapper_class: "flex flex-col items-center w-16 text-center text-inherit",
                                 avatar_class: "size-6 mb-1",
                                 name_class: "entity_entity_name truncate block max-w-full leading-tight",
                                 info_class: "hidden entity_exchanges_info")
            end
          end
        end
      end
    end
  end

  def render_desktop_entities(card_transaction)
    entity_transactions = card_transaction.entity_transactions.order(:id).includes(:entity)

    div(
      class: "col-span-2 py-2 flex items-center justify-center flex-wrap gap-2 hover:opacity-65",
      data: { datatable_target: :entity, id: card_transaction.entities.map(&:id) }
    ) do
      if entity_transactions.one?
        entity_transaction = entity_transactions.first
        button(class: "flex items-center gap-2 rounded-md border border-black px-2 py-1 text-xs text-black") do
          render_entity_link(entity_transaction,
                             wrapper_class: "flex items-center gap-2 text-xs text-inherit",
                             avatar_class: "size-5",
                             name_class: "entity_entity_name",
                             info_class: "hidden entity_exchanges_info")
        end
      else
        Popover(options: { placement: "left" }, class: "flex items-center justify-center") do
          PopoverTrigger(class: "w-full") do
            button(class: "flex items-center gap-2 rounded-md border border-black px-2 py-1 text-xs text-black") do
              render_entity_avatar_stack(entity_transactions, avatar_class: "size-5", limit: 2)
              span { "+" }
            end
          end

          PopoverContent(class: "z-50 !opacity-100 mr-2") do
            div(class: "flex flex-col gap-2 min-w-36") do
              entity_transactions.each do |entity_transaction|
                render_entity_link(entity_transaction,
                                   wrapper_class: "flex items-center gap-2 text-xs text-inherit",
                                   avatar_class: "size-5",
                                   name_class: "entity_entity_name",
                                   info_class: "hidden entity_exchanges_info")
              end
            end
          end
        end
      end
    end
  end

  def render_entity_link(entity_transaction, wrapper_class:, avatar_class:, name_class:, info_class:)
    entity = entity_transaction.entity

    Link(
      href: new_card_transaction_path(user_card_id:, card_transaction: { entity_id: entity.id }, format: :turbo_stream),
      size: :xs,
      class: wrapper_class,
      data: { turbo_frame: "center_container", turbo_prefetch: "false" }
    ) do
      image_tag asset_path("avatars/#{entity.avatar_name}"), class: "bg-white rounded-full #{avatar_class}"
      span(class: name_class) { entity.entity_name }
      span(class: info_class) { entity_exchanges_info(entity_transaction) }
    end
  end

  def render_entity_avatar_stack(entity_transactions, avatar_class:, limit:)
    div(class: "flex items-center") do
      entity_transactions.first(limit).each_with_index do |entity_transaction, index|
        image_tag(
          asset_path("avatars/#{entity_transaction.entity.avatar_name}"),
          class: "bg-white rounded-full border border-white #{avatar_class} #{'-ml-2' if index.positive?}"
        )
      end
    end
  end

  def entity_exchanges_info(entity_transaction)
    info = ""
    info += "[#{from_cent_based_to_float(entity_transaction.price_to_be_returned, 'R$')}]" if entity_transaction.exchanges_count.positive?
    info += " (#{entity_transaction.exchanges_count})" if entity_transaction.exchanges_count > 1
    info
  end
end
