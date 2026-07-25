# frozen_string_literal: true

class Views::Lalas::CardInstallments::Index < Views::Base
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :card_installments, :user_card_id, :category_colour_display_mode

  def initialize(mobile:, card_installments:, user_card_id:,
                 category_colour_display_mode: CategoryColours::DisplayMode::DEFAULT)
    @mobile = mobile
    @card_installments = card_installments
    @user_card_id = user_card_id
    @category_colour_display_mode = CategoryColours::DisplayMode.resolve(category_colour_display_mode)
  end

  def view_template
    if mobile
      card_installments.each do |card_installment|
        card_transaction = card_installment.card_transaction
        presentation = row_presentation(card_transaction)

        render_mobile_card_installment(card_installment, card_transaction, presentation)
      end
    else
      card_installments.each do |card_installment|
        card_transaction = card_installment.card_transaction
        presentation = row_presentation(card_transaction)

        render_card_installment(card_installment, card_transaction, presentation)
      end
    end
  end

  def render_mobile_card_installment(card_installment, card_transaction, presentation)
    turbo_frame_tag dom_id card_installment do
      div(
        class: [ "rounded-lg shadow-sm overflow-hidden my-4 border-2 dark:border-slate-700 dark:shadow-none", presentation.row_classes ].compact.join(" "),
        style: presentation.row_style,
        data: { id: card_installment.id, datatable_target: :row }.merge(presentation.metadata)
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              span(class: "truncate text-md underline underline-offset-[3px]") do
                card_transaction.description
              end

              span(class: installment_count_class(card_transaction.card_installments_count == 1)) do
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
              categories_for(card_transaction).each do |category|
                CategoryBadge(category:, class: "px-2 py-1 text-xs")
              end
            end

            render_mobile_entities(card_transaction)
          end
        end
      end
    end
  end

  def render_card_installment(card_installment, card_transaction, presentation)
    turbo_frame_tag dom_id card_installment do
      div(
        class: [ "grid grid-cols-11 transition-shadow hover:shadow-md", presentation.row_classes ].compact.join(" "),
        style: presentation.row_style,
        draggable: true,
        data: { id: card_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }.merge(presentation.metadata)
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

          span(class: installment_count_class(card_transaction.card_installments_count == 1)) do
            pretty_installments(card_installment.number, card_installment.card_installments_count)
          end
        end

        div(
          class: "col-span-3 py-2 flex items-center justify-center gap-2",
          data: { datatable_target: :category, id: card_transaction.categories.map(&:id) }
        ) do
          categories_for(card_transaction).each do |category|
            CategoryBadge(category:, class: "px-2 py-1 text-sm")
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

  def categories_for(card_transaction)
    card_transaction.category_transactions.sort_by(&:id).filter_map(&:category)
  end

  def row_presentation(card_transaction)
    CategoryColours::RowPresentation.new(categories: categories_for(card_transaction), mode: category_colour_display_mode)
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
        info_class: "entity_exchanges_info text-xs leading-tight",
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

  def installment_count_class(single_installment)
    [
      "p-1 rounded-sm bg-white text-black border border-black shrink-0",
      "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100",
      ("opacity-40" if single_installment)
    ].compact.join(" ")
  end
end
