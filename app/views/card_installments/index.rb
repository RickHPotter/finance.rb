# frozen_string_literal: true

class Views::CardInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::LinkTo
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
              if user_card_id.nil?
                link_to card_transaction.user_card.user_card_name,
                        card_transactions_path(user_card_id: card_transaction.user_card_id, format: :turbo_stream),
                        class: "px-2 py-1 flex items-center justify-center rounded-sm bg-blue-950 border-1 border-slate-200 text-slate-200",
                        data: { turbo_frame: :center_container, turbo_prefetch: false }
              end

              link_to card_transaction.description, edit_card_transaction_path(card_transaction),
                      id: "edit_card_transaction_#{card_transaction.id}",
                      class: "truncate text-md underline underline-offset-[3px]",
                      data: { turbo_frame: :center_container }

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
              card_transaction.categories.each do |category|
                span(class: "py-1 rounded-full text-xs font-medium underline underline-offset-[3px]") do
                  category.category_name
                end
              end
            end

            div(class: "flex justify-between gap-2", data: { datatable_target: :entity, id: card_transaction.entities.map(&:id) }) do
              card_transaction.entities.each do |entity|
                span(class: "px-2 py-1 rounded-full text-xs font-medium bg-slate-100 text-black border border-1 border-gray-500") do
                  entity.entity_name
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
        class: "grid grid-cols-8 border-b border-slate-200 bg-gradient-to-r #{solid_colour_or_gradient(card_transaction)} hover:opacity-60",
        draggable: true,
        data: { id: card_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "p-2 flex items-center justify-between") do
          span(class: "px-1 rounded-sm text-slate-900 mx-auto") { I18n.l(card_installment.date, format: :shorter) }
        end

        div(class: "col-span-3 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
          if user_card_id.nil?
            link_to card_transaction.user_card.user_card_name,
                    card_transactions_path(user_card_id: card_transaction.user_card_id, format: :turbo_stream),
                    class: "px-2 py-1 flex items-center justify-center rounded-sm bg-blue-950 border-1 border-slate-200 text-slate-200",
                    data: { turbo_frame: :center_container, turbo_prefetch: false }
          end

          link_to card_transaction.description, edit_card_transaction_path(card_transaction),
                  id: "edit_card_transaction_#{card_transaction.id}",
                  class: "flex-1 truncate text-md underline underline-offset-[3px]",
                  data: { turbo_frame: :center_container }

          span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
            pretty_installments(card_installment.number, card_installment.card_installments_count)
          end
        end

        div(class: "py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: card_transaction.categories.map(&:id) }) do
          card_transaction.categories.each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
              category.category_name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center flex-wrap gap-2", data: { datatable_target: :entity, id: card_transaction.entities.map(&:id) }) do
          card_transaction.entities.each do |entity|
            span(class: "px-4 rounded-full text-sm bg-purple-100 text-slate-800 border-1 border-black") do
              entity.entity_name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(card_installment.price, "R$")
        end

        div(class: "py-2 flex items-center justify-center") do
          div(class: "flex items-center justify-center px-2 my-1 rounded-md") do
            link_to card_transaction,
                    id: "delete_card_transaction_#{card_transaction.id}",
                    class: "text-red-600 hover:text-red-800 mx-2 bg-white rounded-4xl",
                    data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") } do
              cached_icon :destroy
            end
          end
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
