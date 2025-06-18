# frozen_string_literal: true

class Views::Lalas::CardInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :card_installments, :user_card_id

  def initialize(mobile:, card_installments:, user_card_id:)
    @mobile = mobile
    @card_installments = card_installments
    @user_card_id = user_card_id
  end

  def view_template
    if mobile
      card_installments.each do |card_installment|
        render_mobile_card_installment(card_installment)
      end
    else
      card_installments.each do |card_installment|
        render_card_installment(card_installment)
      end
    end
  end

  def render_mobile_card_installment(card_installment)
    turbo_frame_tag dom_id card_installment do
      card_transaction = card_installment.card_transaction

      div(
        class: "rounded-lg shadow-sm overflow-hidden #{card_transaction.categories&.first&.bg_colour} my-2",
        data: { id: card_installment.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-black text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              span(class: "truncate text-md underline underline-offset-[3px]") do
                card_transaction.user_card.user_card_name
              end

              span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
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

          div(class: "flex items-center justify-between gap-2") do
            div(class: "flex justify-between gap-2", data: { datatable_target: :category, id: card_transaction.categories.map(&:id) }) do
              if card_transaction.categories.count > 2
                first_two = card_transaction.categories.first(2)
                remaining = card_transaction.categories[2..]

                first_two.each do |category|
                  span(class: "py-1 rounded-full text-xs font-medium underline underline-offset-[3px]") do
                    "#{category.name},"
                  end
                end

                Popover(options: { placement: "top" }, class: "rounded-full text-xs font-medium underline underline-offset-[3px]") do
                  PopoverTrigger(class: "w-full") do
                    Button(size: :xs, class: "p-1 text-xs") do
                      "+#{card_transaction.categories.count - 2}"
                    end
                  end

                  PopoverContent(class: "w-40") do
                    remaining.each do |category|
                      p(class: "py-1 rounded-full text-xs font-medium underline underline-offset-[3px]") do
                        category.name
                      end
                    end
                  end
                end
              else

                card_transaction.categories.each do |category|
                  span(class: "py-1 rounded-full text-xs font-medium underline underline-offset-[3px]") do
                    category.name
                  end
                end
              end
            end

            div(class: "flex justify-between gap-2", data: { datatable_target: :entity, id: card_transaction.entities.map(&:id) }) do
              card_transaction.entity_transactions.includes(:entity, :exchanges).each do |entity_transaction|
                entity = entity_transaction.entity
                exchanges_count = entity_transaction.exchanges_count
                price_to_be_returned = entity_transaction.price_to_be_returned
                info = ""
                info += "[#{from_cent_based_to_float(price_to_be_returned, 'R$')}]" if exchanges_count.positive?
                info += " (#{exchanges_count})" if exchanges_count > 1

                span(
                  class: "grid grid-cols-1 text-xs mx-auto",
                  data: { turbo_frame: :center_container, turbo_prefetch: "false" }
                ) do
                  image_tag asset_path("avatars/#{entity.avatar_name}"), class: "bg-white size-4 rounded-full mx-auto"
                  plain "#{entity.entity_name} #{info}"
                end
              end
            end
          end
        end
      end
    end
  end

  def render_card_installment(card_installment)
    turbo_frame_tag dom_id card_installment do
      card_transaction = card_installment.card_transaction

      div(
        class: "grid grid-cols-11 border-b border-slate-200 bg-gradient-to-r #{solid_colour_or_gradient(card_transaction)} hover:opacity-60",
        draggable: true,
        data: { id: card_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "col-span-5 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
          date, time = I18n.l(card_installment.date, format: :shorter).split(",")
          div(class: "grid grid-cols-1") do
            span(class: "rounded-xs text-slate-900 text-xs mr-auto") { date }
            span(class: "rounded-xs text-slate-900 text-xs mr-auto") { time }
          end

          span(
            id: "edit_card_transaction_#{card_transaction.id}",
            class: "flex-1 truncate text-md underline underline-offset-[3px]"
          ) do
            card_transaction.description
          end

          span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
            pretty_installments(card_installment.number, card_installment.card_installments_count)
          end
        end

        div(class: "col-span-3 py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: card_transaction.categories.map(&:id) }) do
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
            card_transaction.categories.each do |category|
              span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
                category.name
              end
            end
          end
        end

        div(
          class: "col-span-2 py-2 flex items-center justify-center flex-wrap gap-2",
          data: { datatable_target: :entity, id: card_transaction.entities.map(&:id) }
        ) do
          card_transaction.entity_transactions.includes(:entity).each do |entity_transaction|
            entity = entity_transaction.entity
            exchanges_count = entity_transaction.exchanges_count
            price_to_be_returned = entity_transaction.price_to_be_returned
            info = ""
            info += "[#{from_cent_based_to_float(price_to_be_returned, 'R$')}]" if exchanges_count.positive?
            info += " (#{exchanges_count})" if exchanges_count > 1

            span(
              class: "grid grid-cols-1 text-xs mx-auto",
              data: { turbo_frame: :center_container, turbo_prefetch: "false" }
            ) do
              image_tag asset_path("avatars/#{entity.avatar_name}"), class: "bg-white size-4 rounded-full mx-auto"
              plain "#{entity.entity_name} #{info}"
            end
          end
        end

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto mr-1") do
          from_cent_based_to_float(card_installment.price, "R$")
        end
      end
    end
  end

  def solid_colour_or_gradient(card_transaction)
    if card_transaction.categories.count > 1
      return [
        card_transaction.categories.first.from_bg, *card_transaction.categories[1..-2].map(&:via_bg),
        card_transaction.categories.last.to_bg
      ].join(" ")
    end

    card_transaction.categories.first&.bg_colour
  end
end
