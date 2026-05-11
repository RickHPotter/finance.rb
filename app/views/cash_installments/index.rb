# frozen_string_literal: true

class Views::CashInstallments::Index < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper
  include ColoursHelper

  attr_reader :mobile, :cash_installments, :index_context

  def initialize(mobile:, cash_installments:, index_context: {})
    @mobile = mobile
    @cash_installments = cash_installments
    @index_context = index_context
  end

  def view_template
    if mobile
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction
        avatar_name = retrieve_avatar_name(cash_transaction)
        style = solid_or_gradient_style(categories_for(cash_transaction))

        render_mobile_cash_installment(cash_installment, cash_transaction, style, avatar_name)
      end
    else
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction
        avatar_name = retrieve_avatar_name(cash_transaction)
        style = solid_or_gradient_style(categories_for(cash_transaction))

        render_cash_installment(cash_installment, cash_transaction, style, avatar_name)
      end
    end
  end

  def retrieve_avatar_name(cash_transaction)
    return "others/card.png" if cash_transaction.card_advance? || cash_transaction.card_payment?
    return "others/bank.png" if cash_transaction.investment?

    nil
  end

  def render_mobile_cash_installment(cash_installment, cash_transaction, style, avatar_name)
    turbo_frame_tag dom_id cash_installment do
      should_display_link_to_pay = should_display_link_to_pay?(cash_installment)

      render Views::CashInstallments::PayModal.new(cash_installment:, index_context:) if should_display_link_to_pay || cash_transaction.card_payment?

      div(class: "relative") do
        div(
          class: "absolute -top-2 right-0 p-1 rounded-t-lg bg-yellow-400 shadow-sm border border-yellow-600 font-lekton font-bold
                  text-sm z-40 #{'animate-pulse' if should_display_link_to_pay}"
        ) do
          from_cent_based_to_float(cash_installment.balance, "R$")
        end
      end

      div(
        class: "rounded-lg shadow-sm overflow-visible my-4 border-2 cursor-pointer #{'animate-pulse' if should_display_link_to_pay}",
        style: "background-clip: padding-box; #{style}",
        data: { id: cash_installment.id, datatable_target: :row, action: "mousedown->datatable#preventRangeSelection click->datatable#toggleCardSelection" }
      ) do
        render_row_checkbox(cash_installment, cash_transaction, mobile: true)

        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              render_description_link(cash_transaction, class: "cash_transaction_description truncate text-md underline underline-offset-[3px]")

              span(class: "shrink p-1 rounded-sm bg-white text-black border border-black #{'opacity-40' if cash_transaction.cash_installments_count == 1}") do
                pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1 flex items-center") do
              render_action_menu(cash_installment, cash_transaction, payable: should_display_link_to_pay)

              span(class: "whitespace-nowrap pl-2") do
                format = cash_transaction.investment? ? "%B %Y" : :short
                I18n.l(cash_installment.date, format:)
              end
            end

            div(class: "whitespace-nowrap", title: from_cent_based_to_float(cash_transaction.price, "R$")) do
              from_cent_based_to_float(cash_installment.price, "R$")
            end
          end

          div(class: "flex flex-wrap items-center gap-1") do
            render_mobile_categories(cash_transaction)

            render_mobile_entities(cash_transaction, avatar_name)
          end
        end
      end
    end
  end

  def render_cash_installment(cash_installment, cash_transaction, style, avatar_name)
    turbo_frame_tag dom_id cash_installment do
      should_display_link_to_pay = should_display_link_to_pay?(cash_installment)
      text_style = auto_text_color(categories_for(cash_transaction).first&.hex_colour)

      render Views::CashInstallments::PayModal.new(cash_installment:, index_context:) if should_display_link_to_pay || cash_transaction.card_payment?

      div(
        class: [
          "group relative z-0 grid grid-cols-12 transition-all hover:z-40",
          "[&>*:not([data-row-background])]:relative [&>*:not([data-row-background])]:z-10",
          "[&.exchange-sheet-active>*:not([data-row-background])]:z-[60]",
          ("animate-pulse" if should_display_link_to_pay)
        ].compact.join(" "),
        style: text_style,
        draggable: true,
        data: { id: cash_installment.id,
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

        render_row_checkbox(cash_installment, cash_transaction) do
          div(class: "flex-1 flex items-center justify-between gap-2 rounded-sm pl-2") do
            render_action_menu(cash_installment, cash_transaction, payable: should_display_link_to_pay)

            date, time = I18n.l(cash_installment.date, format: :shorter).split(",")
            div(class: "grid grid-cols-1 mr-auto") do
              span(class: "rounded-xs text-xs mr-auto") { date }
              span(class: "rounded-xs text-xs mr-auto") { time }
            end
          end
        end

        div(class: "col-span-4 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
          render_description_link(cash_transaction, class: "cash_transaction_description flex-1 truncate text-md underline underline-offset-[3px]")

          span(class: "p-1 rounded-sm bg-white text-black border border-black shrink-0 #{'opacity-40' if cash_installment.cash_installments_count == 1}") do
            pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
          end
        end

        render_desktop_categories(cash_transaction)

        render_desktop_entities(cash_transaction, avatar_name)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto",
            title: from_cent_based_to_float(cash_transaction.price, "R$")) do
          from_cent_based_to_float(cash_installment.price, "R$")
        end

        div(class: "flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto mr-1") do
          div(class: "p-1 rounded-md shadow-sm border border-black") do
            from_cent_based_to_float(cash_installment.balance, "R$")
          end
        end
      end
    end
  end

  def should_display_link_to_pay?(cash_installment)
    !cash_installment.paid?
  end

  def render_description_link(cash_transaction, class:)
    if cash_transaction.investment?
      default_year = cash_transaction.year
      active_month_years = "[#{Date.new(cash_transaction.year, cash_transaction.month).strftime('%Y%m')}]"
      investment = { user_bank_account_id: cash_transaction.user_bank_account_id, investment_type_id: cash_transaction.investment_type_id }

      link_to cash_transaction.description,
              investments_path(investment:, default_year:, active_month_years:, format: :turbo_stream),
              class:,
              title: cash_transaction.comment,
              data: { turbo_frame: "_top", turbo_prefetch: false }
    elsif cash_transaction.card_advance?
      card_ = cash_transaction.card_installments.first || CardTransaction.find_by(advance_cash_transaction: cash_transaction)
      default_year = card_.year
      active_month_years = "[#{Date.new(card_.year, card_.month).strftime('%Y%m')}]"

      link_to cash_transaction.description,
              card_transactions_path(user_card_id: cash_transaction.user_card_id, default_year:, active_month_years:, format: :turbo_stream),
              class:,
              title: cash_transaction.comment,
              data: { turbo_frame: "_top", turbo_prefetch: false }
    else
      link_to cash_transaction.description,
              edit_cash_transaction_path(cash_transaction),
              id: "edit_cash_transaction_#{cash_transaction.id}",
              class:,
              title: cash_transaction.comment,
              data: { turbo_frame: "_top" }
    end
  end

  def render_action_menu(cash_installment, cash_transaction, payable:)
    Popover(options: { trigger: "click", placement: "bottom-start" }, class: "relative z-50 shrink-0") do
      PopoverTrigger(class: "flex") do
        button(
          type: :button,
          id: "cash_installment_actions_#{cash_installment.id}",
          class: "rounded-sm bg-white/90 p-0.5 text-slate-900 shadow-sm ring-1 ring-black/20 transition hover:bg-slate-900 hover:text-white [&_svg]:size-4",
          title: I18n.t("actions_column")
        ) do
          cached_icon(:ellipsis)
        end
      end

      PopoverContent(class: "z-60 opacity-100! min-w-44 p-1") do
        div(class: "flex flex-col gap-1") do
          action_menu_link(action_message(:analyse), cash_transaction_path(cash_transaction))
          action_menu_button(model_attribute(cash_installment, :pay), modal_id: "cashInstallmentModal_#{cash_installment.id}") if payable
          if cash_transaction.card_payment?
            action_menu_button(model_attribute(cash_installment, :change_date), modal_id: "cashInstallmentModal_#{cash_installment.id}")
          end
          action_menu_link(action_message(:duplicate), duplicate_cash_transaction_path(cash_transaction)) if cash_transaction.can_be_destroyed?
          action_menu_destroy_link(cash_transaction) if cash_transaction.can_be_destroyed?
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

  def action_menu_button(label, modal_id:)
    button(
      type: :button,
      class: action_menu_item_class,
      data: {
        modal_target: modal_id,
        modal_toggle: modal_id,
        action: "click->ruby-ui--popover#close"
      }
    ) do
      label
    end
  end

  def action_menu_destroy_link(cash_transaction)
    LinkWithConfirmation(
      id: "cash_transaction_menu_destroy_#{cash_transaction.id}",
      text: action_message(:destroy),
      link_params: {
        href: cash_transaction_path(cash_transaction),
        id: "delete_cash_transaction_#{cash_transaction.id}",
        variant: :ghost,
        class: action_menu_item_class,
        data: {
          turbo_method: :delete,
          turbo_frame: "_top"
        }
      }
    )
  end

  def action_menu_item_class
    "w-full justify-start rounded-md px-3 py-2 text-left text-sm font-semibold text-slate-700 no-underline transition-colors hover:bg-slate-100 hover:no-underline"
  end

  def render_mobile_entities(cash_transaction, avatar_name)
    items = cash_entity_popover_items(cash_transaction, avatar_name, :id)

    render Views::Entities::Popover.new(
      items:,
      mobile: true,
      target_ids: cash_transaction.entities.map(&:id),
      trigger_label: pluralise_model(Entity, items.count).upcase,
      variant: :cash
    )
  end

  def render_desktop_entities(cash_transaction, avatar_name)
    render Views::Entities::Popover.new(
      items: cash_entity_popover_items(cash_transaction, avatar_name, :entity_id),
      mobile: false,
      target_ids: cash_transaction.entities.map(&:id),
      trigger_label: "",
      variant: :cash
    )
  end

  def render_mobile_categories(cash_transaction)
    render Views::Categories::Popover.new(
      items: cash_category_popover_items(cash_transaction),
      mobile: true,
      target_ids: cash_transaction.categories.map(&:id),
      trigger_label: pluralise_model(Category, categories_for(cash_transaction).count).upcase,
      variant: :cash
    )
  end

  def render_desktop_categories(cash_transaction)
    render Views::Categories::Popover.new(
      items: cash_category_popover_items(cash_transaction),
      mobile: false,
      target_ids: cash_transaction.categories.map(&:id),
      trigger_label: "",
      variant: :cash
    )
  end

  def categories_for(cash_transaction)
    cash_transaction.category_transactions.sort_by(&:id).filter_map(&:category)
  end

  def cash_category_popover_items(cash_transaction)
    categories_for(cash_transaction).map do |category|
      {
        name: category.name
      }
    end
  end

  def entities_for(cash_transaction, sort_key)
    cash_transaction.entity_transactions.includes(:entity).sort_by(&sort_key)
  end

  def cash_entity_popover_items(cash_transaction, avatar_name, sort_key)
    entities_for(cash_transaction, sort_key).map do |entity_transaction|
      entity = entity_transaction.entity

      next if entity.nil?

      {
        name: entity.entity_name,
        avatar_name: avatar_name || entity.avatar_name,
        name_href: new_cash_transaction_path(cash_transaction: { entity_id: entity.id }),
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

  def render_row_checkbox(cash_installment, cash_transaction, mobile: false)
    div(class: "flex items-center gap-1 relative px-2", data: { row_actions: true }) do
      label(class: "group inline-flex cursor-pointer items-center justify-center", data: { action: "mousedown->datatable#preventRangeSelection" }) do
        input(
          type: :checkbox,
          value: cash_installment.id,
          class: "peer sr-only",
          data: {
            datatable_target: :checkbox,
            action: "mousedown->datatable#preventRangeSelection click->datatable#toggleSelection",
            bulk_price_cents: cash_installment.price,
            bulk_record_id: cash_transaction.id,
            bulk_label: [
              cash_transaction.description,
              "·",
              pretty_installments(cash_installment.number, cash_installment.cash_installments_count),
              "·",
              from_cent_based_to_float(cash_installment.price, "R$")
            ].join,
            bulk_pay_eligible: cash_installment.bulk_pay_eligible?.to_s,
            bulk_transfer_eligible: cash_installment.bulk_transfer_eligible?.to_s,
            bulk_subscription_eligible: cash_transaction.bulk_subscription_eligible?.to_s
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
