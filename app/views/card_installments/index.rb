# frozen_string_literal: true

class Views::CardInstallments::Index < Views::Base # rubocop:disable Metrics/ClassLength
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
        class: "rounded-lg shadow-sm overflow-visible my-2",
        style: "background-clip: padding-box; #{style}",
        data: { id: card_installment.id, datatable_target: :row, action: "mousedown->datatable#preventRangeSelection click->datatable#toggleCardSelection" }
      ) do
        render_row_checkbox(card_installment, card_transaction, mobile: true)

        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              if user_card_id.nil?
                link_to card_transaction.user_card.user_card_name,
                        card_transactions_path(user_card_id: card_transaction.user_card_id, format: :turbo_stream),
                        class: "px-2 py-1 flex items-center justify-center rounded-sm bg-blue-800 border border-slate-200 text-slate-200",
                        data: { turbo_frame: "_top", turbo_prefetch: false }
              end

              render_description_link(card_transaction, class: "truncate text-md underline underline-offset-[3px]")

              span(class: "p-1 rounded-sm bg-white text-black border border-black shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
                pretty_installments(card_installment.number, card_installment.card_installments_count)
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1 flex items-center") do
              render_action_menu(card_installment, card_transaction)

              span(class: "whitespace-nowrap pl-2") { I18n.l(card_installment.date, format: :short) }
            end

            div(class: "whitespace-nowrap", title: from_cent_based_to_float(card_transaction.price, "R$")) do
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

  def render_action_menu(card_installment, card_transaction)
    Popover(options: { trigger: "click", placement: "bottom-start" }, class: "relative z-50 shrink-0") do
      PopoverTrigger(class: "flex") do
        button(
          type: :button,
          id: "card_installment_actions_#{card_installment.id}",
          class: action_menu_button_class,
          title: I18n.t("actions_column"),
          aria: { label: I18n.t("actions_column") }
        ) do
          cached_icon(:ellipsis)
        end
      end

      PopoverContent(class: "z-60 opacity-100! min-w-44 p-1") do
        div(class: "flex flex-col gap-1") do
          action_menu_link(action_message(:analyse), card_transaction_path(card_transaction))
          action_menu_link(action_message(:duplicate), duplicate_card_transaction_path(card_transaction)) unless card_transaction.card_advance_category?
          action_menu_destroy_link(card_installment, card_transaction) if card_transaction.can_be_destroyed?
        end
      end
    end
  end

  def action_menu_link(label, href)
    link_to label,
            href,
            class: action_menu_item_class,
            data: { turbo_frame: "_top", turbo_prefetch: false, action: "click->ruby-ui--popover#close" }
  end

  def action_menu_destroy_link(card_installment, card_transaction)
    LinkWithConfirmation(
      id: "card_transaction_menu_destroy_#{card_transaction.id}_#{card_installment.id}",
      text: action_message(:destroy),
      link_params: {
        href: card_transaction_path(card_transaction, card_installment_id: card_installment.id),
        variant: :ghost,
        id: "delete_card_transaction_#{card_transaction.id}_#{card_installment.id}",
        class: action_menu_item_class,
        data: {
          turbo_method: :delete,
          turbo_frame: "_top"
        }
      }
    )
  end

  def render_card_installment(card_installment, card_transaction, style)
    turbo_frame_tag dom_id card_installment do
      text_style = auto_text_color(card_transaction.category_transactions.order(:id).map(&:category).first&.hex_colour)

      div(
        class: [
          "group relative z-0 grid grid-cols-12 transition-all hover:z-40",
          "[&>*:not([data-row-background])]:relative [&>*:not([data-row-background])]:z-10",
          "[&.exchange-sheet-active>*:not([data-row-background])]:z-[60]"
        ].join(" "),
        style: text_style,
        draggable: true,
        data: { id: card_installment.id,
                datatable_target: :row,
                action: [
                  "mousedown->datatable#preventRangeSelection",
                  "dragstart->datatable#start",
                  "dragover->datatable#activate",
                  "drop->datatable#drop"
                ].join(" ") }
      ) do
        div(
          class: "pointer-events-none absolute inset-0 z-0 transition-all duration-150 " \
                 "group-hover:ring-2 group-hover:ring-slate-700/80 group-hover:ring-inset",
          style: "background-clip: padding-box; #{style}",
          data: { row_background: true }
        )

        render_row_checkbox(card_installment, card_transaction, wrapper_class: "col-span-5 flex items-center gap-1 relative px-2") do
          div(class: "flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
            date, time = I18n.l(card_installment.date, format: :shorter).split(",")
            div(class: "grid grid-cols-1") do
              span(class: "rounded-xs text-xs mr-auto") { date }
              span(class: "rounded-xs text-xs mr-auto") { time }
            end

            if user_card_id.nil?
              link_to card_transaction.user_card.user_card_name,
                      card_transactions_path(user_card_id: card_transaction.user_card_id, format: :turbo_stream),
                      class: "px-2 py-1 ml-2 flex-1 items-center justify-center rounded-sm bg-blue-800 border border-slate-200 text-slate-200",
                      data: { turbo_frame: "_top", turbo_prefetch: false }
            end

            render_description_link(card_transaction, class: "flex-5 truncate text-md underline underline-offset-[3px]")

            span(class: "p-1 rounded-sm bg-white text-black border border-black shrink-0 #{'opacity-40' if card_transaction.card_installments_count == 1}") do
              pretty_installments(card_installment.number, card_installment.card_installments_count)
            end
          end
        end

        render_desktop_categories(card_transaction)

        render_desktop_entities(card_transaction)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto",
            title: from_cent_based_to_float(card_transaction.price, "R$")) do
          from_cent_based_to_float(card_installment.price, "R$")
        end

        div(class: "py-2 flex items-center justify-center") do
          div(class: "flex items-center justify-end gap-1 px-2 ml-auto") do
            render_analyse_link(card_transaction)

            link_to(
              duplicate_card_transaction_path(card_transaction),
              class: action_button_class,
              title: action_message(:duplicate),
              aria: { label: action_message(:duplicate) },
              data: { turbo_frame: "_top", turbo_prefetch: false }
            ) do
              cached_icon :copy
            end

            LinkWithConfirmation(
              id: "#{card_transaction.id}_#{card_installment.id}",
              icon: :destroy,
              link_params: {
                href: card_transaction_path(card_transaction, card_installment_id: card_installment.id),
                size: :xs,
                id: "delete_card_transaction_#{card_transaction.id}_#{card_installment.id}",
                class: destructive_action_button_class,
                data: { turbo_method: :delete, turbo_frame: "_top", turbo_prefetch: "false" }
              }
            )
          end
        end
      end
    end
  end

  def render_analyse_link(card_transaction, mobile: false)
    link_to card_transaction_path(card_transaction),
            class: analyse_link_class(mobile),
            title: action_message(:analyse),
            aria: { label: action_message(:analyse) },
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      cached_icon(:eye)
    end
  end

  def analyse_link_class(_mobile)
    action_button_class
  end

  def action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-slate-300 bg-white text-slate-800 " \
      "shadow-sm transition hover:border-slate-900 hover:bg-slate-900 hover:text-white [&_svg]:size-4"
  end

  def destructive_action_button_class
    "#{action_button_class} border-red-200 text-red-700 hover:border-red-600 hover:bg-red-600 hover:text-white [&_svg]:!text-current"
  end

  def action_menu_button_class
    "rounded-sm bg-white/90 p-0.5 text-slate-900 shadow-sm ring-1 ring-black/20 transition hover:bg-slate-900 hover:text-white [&_svg]:size-4"
  end

  def action_menu_item_class
    "w-full justify-start rounded-md px-3 py-2 text-left text-sm font-semibold text-slate-700 no-underline transition-colors hover:bg-slate-100 hover:no-underline"
  end

  def render_description_link(card_transaction, class:)
    link_to card_transaction.description,
            edit_card_transaction_path(card_transaction),
            id: "edit_card_transaction_#{card_transaction.id}",
            class:,
            title: card_transaction.comment,
            data: { turbo_frame: "_top", turbo_prefetch: false }
  end

  def render_mobile_entities(card_transaction)
    items = entity_popover_items(card_transaction)

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
      items: entity_popover_items(card_transaction),
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

  def entities_for(card_transaction)
    card_transaction.entity_transactions.includes(:entity).sort_by do |entity_transaction|
      [ entity_transaction.entity&.entity_name.to_s, entity_transaction.id.to_i ]
    end
  end

  def entity_popover_items(card_transaction)
    entities_for(card_transaction).map do |entity_transaction|
      entity = entity_transaction.entity
      href = entity_links ? new_card_transaction_path(user_card_id:, card_transaction: { entity_id: entity.id }) : nil

      {
        name: entity.entity_name,
        avatar_name: entity.avatar_name,
        name_href: href,
        name_data: { turbo_frame: "_top", turbo_prefetch: "false" },
        info_class: "entity_exchanges_info text-xs leading-tight",
        info_component: exchange_info_component(entity_transaction)
      }
    end
  end

  def entity_exchanges_info(entity_transaction)
    return if entity_transaction.exchanges_count.zero?

    [
      "[#{from_cent_based_to_float(entity_transaction.price_to_be_returned, 'R$')}]",
      "(#{entity_transaction.exchanges_count})"
    ].join(" ")
  end

  def exchange_info_component(entity_transaction)
    return if entity_transaction.exchanges_count.zero?

    Views::EntityTransactions::ExchangeStateSheet.new(
      entity_transaction:,
      trigger_text: entity_exchanges_info(entity_transaction)
    )
  end

  def card_category_popover_items(card_transaction)
    card_transaction.category_transactions.sort_by(&:id).filter_map(&:category).map do |category|
      {
        name: category.name,
        style: "border-color: black"
      }
    end
  end

  def render_row_checkbox(card_installment, card_transaction, mobile: false, wrapper_class: nil)
    div(class: wrapper_class || "flex items-center gap-1 relative px-2 #{'pt-2' if mobile}") do
      label(class: "group inline-flex cursor-pointer items-center justify-center", data: { action: "mousedown->datatable#preventRangeSelection" }) do
        input(
          type: :checkbox,
          value: card_installment.id,
          class: "peer sr-only",
          data: {
            datatable_target: :checkbox,
            action: "mousedown->datatable#preventRangeSelection click->datatable#toggleSelection",
            bulk_price_cents: card_installment.price,
            bulk_record_id: card_transaction.id,
            bulk_pay_eligible: false.to_s,
            bulk_transfer_eligible: false.to_s,
            bulk_subscription_eligible: card_transaction.bulk_subscription_eligible?.to_s
          }
        )

        unless mobile
          span(
            class: "flex items-center justify-center rounded-full border border-zinc-700 bg-white shadow-sm transition-all
                peer-checked:border-blue-600 peer-checked:bg-blue-600 peer-checked:text-white
                peer-focus:ring-2 peer-focus:ring-blue-300 size-4"
          ) do
            span(class: "text-2xs font-bold opacity-0 transition-opacity peer-checked:opacity-100") { "✓" }
          end
        end
      end

      yield if block_given?
    end
  end
end
