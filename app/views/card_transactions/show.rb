# frozen_string_literal: true

class Views::CardTransactions::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :card_transaction

  def initialize(card_transaction:)
    @card_transaction = card_transaction
  end

  def view_template
    render_pay_in_advance_modal

    turbo_frame_tag :center_container do
      div(class: "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm sm:rounded-3xl sm:p-6") do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_grid
          installments_and_invoices_section
          exchanges_section
          links_section
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 sm:text-4xl") { card_transaction.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          special_badges
        end

        p(class: "mt-3 max-w-3xl text-sm leading-6 text-slate-600") { card_transaction.comment } if card_transaction.comment.present?
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(action_message(:edit), edit_card_transaction_path(card_transaction), variant: :edit)
        dashboard_action(action_message(:duplicate), duplicate_card_transaction_path(card_transaction), variant: :duplicate) if duplicate_allowed?
        destroy_action
        pay_in_advance_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(CardTransaction, :price), money(card_transaction.price), emphasis: true)
        dashboard_stat(model_attribute(CardTransaction, :date), localized_date(card_transaction.date))
        dashboard_stat(model_attribute(CardTransaction, :month), I18n.l(Date.new(card_transaction.year, card_transaction.month, 1), format: "%B %Y"))
        dashboard_stat(model_attribute(CardTransaction, :user_card_id), card_name)
      end

      div(class: "mt-4 grid gap-3 border-t border-slate-200 pt-4 xl:grid-cols-2") do
        allocation_group(model_attribute(CardTransaction, :categories), categories.map(&:name))
        allocation_group(model_attribute(CardTransaction, :entities), entities.map(&:entity_name))
      end
    end
  end

  def installments_and_invoices_section
    section_card("Installments and Invoices") do
      if mobile?
        div(class: "space-y-2") do
          installments.each do |installment|
            installment_mobile_card(installment, installment.cash_transaction)
          end
        end
      else
        div(class: "grid gap-4 xl:grid-cols-2 xl:items-start") do
          div(class: "overflow-hidden rounded-2xl border border-slate-200") do
            div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
              span(class: "col-span-2 text-center") { model_attribute(CardInstallment, :number) }
              span(class: "col-span-3") { model_attribute(CardTransaction, :reference_month_year) }
              span(class: "col-span-3") { model_attribute(CardInstallment, :date) }
              span(class: "col-span-2 text-right") { model_attribute(CardInstallment, :price) }
              span(class: "col-span-2 text-right") { model_attribute(CardInstallment, :paid) }
            end

            installments.each do |installment|
              installment_row(installment)
            end
          end

          if invoice_cash_transactions.present?
            div(class: "overflow-hidden rounded-2xl border border-slate-200") do
              div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
                span(class: "col-span-2 text-center") { model_attribute(CardInstallment, :number) }
                span(class: "col-span-3") { model_attribute(CardTransaction, :reference_month_year) }
                span(class: "col-span-3") { model_attribute(CashTransaction, :date) }
                span(class: "col-span-2 text-right") { model_attribute(CashTransaction, :price) }
                span(class: "col-span-2 text-right") { model_attribute(CashTransaction, :paid) }
              end

              invoice_cash_transactions.each_with_index do |cash_transaction, index|
                invoice_row(cash_transaction, index + 1, invoice_cash_transactions.count)
              end
            end
          else
            div(class: "space-y-2") do
              empty_state_card
            end
          end
        end
      end
    end
  end

  def links_section
    section_card(I18n.t("dashboards.sections.links")) do
      div(class: "space-y-2") do
        if card_transaction.subscription.present?
          link_item(model_attribute(CardTransaction, :subscription_id), card_transaction.subscription.description,
                    edit_subscription_path(card_transaction.subscription))
        end
        if card_transaction.advance_cash_transaction.present?
          link_item(I18n.t("dashboards.card_transactions.advance_cash_transaction"), card_transaction.advance_cash_transaction.description,
                    cash_transaction_path(card_transaction.advance_cash_transaction))
        end
        reference_link_item
        descendants_link_item
        empty_state if dashboard_links_empty?
      end
    end
  end

  def exchanges_section
    section_card(I18n.t("dashboards.card_transactions.exchanges")) do
      if exchange_entity_transactions.present?
        div(class: "space-y-2") do
          exchange_entity_transactions.each do |entity_transaction|
            exchange_entity_transaction_card(entity_transaction)
          end
        end
      else
        empty_state
      end
    end
  end

  def section_card(title, &)
    section(class: "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 sm:rounded-3xl sm:p-4",
            data: { controller: "show-section-card", show_section_card_open_value: true }) do
      button(type: :button, class: "flex w-full items-center justify-between gap-3 text-left",
             data: { action: "show-section-card#toggle", show_section_card_target: "button" }) do
        h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500") { title }
        span(class: "text-lg font-semibold leading-none text-slate-500", data: { show_section_card_target: "icon" }) { "−" }
      end

      div(class: "mt-4", data: { show_section_card_target: "content" }, &)
    end
  end

  def dashboard_stat(label, value, emphasis: false)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "#{emphasis ? 'text-xl sm:text-2xl' : 'text-base sm:text-lg'} mt-2 font-bold text-slate-950") { value.to_s }
    end
  end

  def installment_row(installment)
    div(class: "grid grid-cols-12 items-center border-t px-4 py-3 text-sm #{installment_row_class(installment)}") do
      span(class: "col-span-2 text-center font-bold text-slate-950") { pretty_installments(installment.number, installment.card_installments_count) }
      span(class: "col-span-3 font-semibold text-slate-950") { installment.month_year }
      span(class: "col-span-3 font-semibold text-slate-950") { localized_date(installment.date) }
      span(class: "col-span-2 text-right font-bold text-slate-950") { money(installment.price) }
      span(class: "col-span-2 flex justify-end") { installment_status_badge(installment) }
    end
  end

  def installment_mobile_card(installment, cash_transaction)
    div(class: "overflow-hidden rounded-xl border #{installment_mobile_card_class(installment)}") do
      combined_mobile_installment_content(installment, cash_transaction)
    end
  end

  def allocation_group(label, names)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500") { label }

      if names.empty?
        p(class: "mt-2 text-sm text-slate-500") { I18n.t("dashboards.empty") }
      else
        div(class: "mt-3 flex flex-wrap justify-center gap-2") do
          if label == model_attribute(CardTransaction, :categories)
            categories.each do |category|
              span(
                class: "flex min-h-12 items-center justify-center break-words rounded-sm border border-black px-2 py-1 text-center text-sm text-black",
                style: "background: #{category.hex_colour}",
                title: category.name
              ) { category.name }
            end
          else
            entities.each do |entity|
              div(class: "flex min-h-12 items-center gap-2 rounded-lg border border-slate-400 bg-white px-2 py-1 text-sm text-black", title: entity.entity_name) do
                image_tag(asset_path("avatars/#{entity.avatar_name}"), class: "h-6 w-6 rounded-full") if entity.avatar_name.present?
                span(class: "break-words") { entity.entity_name }
              end
            end
          end
        end
      end
    end
  end

  def status_badge
    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{paid_state_class}") do
      paid_state_label
    end
  end

  def special_badges
    special_labels.each do |label|
      span(class: "rounded-full border border-amber-300 bg-amber-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-amber-900") { label }
    end
  end

  def dashboard_action(label, href, variant:)
    Button(link: href, variant: dashboard_action_variant(variant), class: dashboard_action_class(variant), data: { turbo_frame: "_top", turbo_prefetch: false }) do
      label
    end
  end

  def pay_in_advance_action
    return unless pay_in_advance_available?

    Button(type: :button, variant: dashboard_action_variant(:pay), class: dashboard_action_class(:pay),
           data: { modal_target: pay_in_advance_modal_id, modal_toggle: pay_in_advance_modal_id }) do
      model_attribute(CardTransaction, :pay_in_advance)
    end
  end

  def destroy_action
    return unless card_transaction.can_be_destroyed?

    LinkWithConfirmation(
      id: "card_transaction_dashboard_destroy_#{card_transaction.id}",
      text: action_message(:destroy),
      link_params: {
        href: card_transaction_path(card_transaction),
        variant: :destructive,
        id: "delete_card_transaction_#{card_transaction.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
      }
    )
  end

  def dashboard_action_class(variant)
    default = "border-slate-300 text-slate-700 hover:bg-slate-100"
    return default if %i[primary outline].include?(variant)

    case variant
    when :edit then "border-sky-500 bg-sky-100 text-sky-900 hover:border-sky-400 hover:bg-sky-500 hover:text-white"
    when :duplicate then "border-orange-500 bg-orange-100 text-orange-900 hover:border-orange-400 hover:bg-orange-500 hover:text-white"
    when :pay then "border-green-500 bg-green-100 text-green-900 hover:border-green-400 hover:bg-green-500 hover:text-white"
    when :destroy then "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white"
    else default
    end
  end

  def dashboard_action_variant(variant)
    return :purple if variant == :edit

    :outline
  end

  def card_index_path
    card_transactions_path(
      user_card_id: card_transaction.user_card_id,
      default_year: card_transaction.year,
      active_month_years: active_month_years_param(card_transaction.year, card_transaction.month)
    )
  end

  def active_month_years_param(year, month)
    [ Date.new(year, month, 1).strftime("%Y%m").to_i ].to_json
  end

  def link_item(label, value, href)
    link_to href, class: "block rounded-2xl border border-slate-200 bg-white px-3 py-3 transition hover:border-slate-400 sm:px-4",
                  data: { turbo_frame: "_top", turbo_prefetch: false } do
      p(class: "text-2xs font-bold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "mt-1 wrap-break-word text-sm font-bold text-slate-950") { value }
    end
  end

  def exchange_item(exchange)
    href = exchange.cash_transaction.present? ? cash_transaction_path(exchange.cash_transaction) : "#"
    link_item(exchange.exchange_type.to_s.humanize, "#{money(exchange.price)} - #{localized_date(exchange.date)}", href)
  end

  def exchange_entity_transaction_card(entity_transaction)
    div(class: "rounded-2xl border border-slate-200 bg-white px-3 py-3 sm:px-4") do
      if mobile?
        div(class: "space-y-2") do
          div(class: "flex min-w-0 items-center gap-2") do
            if entity_transaction.entity&.avatar_name.present?
              image_tag(asset_path("avatars/#{entity_transaction.entity.avatar_name}"),
                        class: "h-8 w-8 rounded-full")
            end
            span(class: "break-words text-sm font-bold text-slate-950") { entity_transaction.entity.entity_name }
          end

          div(class: "flex flex-wrap items-center gap-2") do
            exchange_entity_role_badge(entity_transaction)
            exchange_entity_bound_badge(entity_transaction)
            exchange_entity_summary_badge(exchange_entity_summary_text(entity_transaction))
          end
        end
      else
        div(class: "flex items-start gap-3") do
          div(class: "flex min-w-0 items-start gap-2") do
            if entity_transaction.entity&.avatar_name.present?
              image_tag(asset_path("avatars/#{entity_transaction.entity.avatar_name}"),
                        class: "h-8 w-8 rounded-full")
            end

            div(class: "min-w-0") do
              div(class: "flex flex-wrap items-center gap-2") do
                span(class: "truncate text-sm font-bold text-slate-950") { entity_transaction.entity.entity_name }
                exchange_entity_role_badge(entity_transaction)
                exchange_entity_bound_badge(entity_transaction)
                exchange_entity_summary_badge(exchange_entity_summary_text(entity_transaction))
              end
            end
          end
        end
      end

      if entity_transaction.exchanges.present?
        if mobile?
          div(class: "mt-3 space-y-2") do
            entity_transaction.exchanges.order(:number, :date).each do |exchange|
              exchange_mobile_card(exchange)
            end
          end
        else
          div(class: "mt-3 overflow-hidden rounded-xl border border-slate-200") do
            div(class: "grid grid-cols-12 bg-slate-950 px-3 py-2 text-2xs font-bold uppercase tracking-[0.16em] text-white") do
              span(class: "col-span-2 text-center") { model_attribute(CardInstallment, :number) }
              span(class: "col-span-4") { model_attribute(Exchange, :month_year) }
              span(class: "col-span-4") { model_attribute(CardInstallment, :date) }
              span(class: "col-span-2 text-right") { model_attribute(Exchange, :price) }
            end

            entity_transaction.exchanges.order(:number, :date).each do |exchange|
              exchange_row(exchange)
            end
          end
        end
      else
        p(class: "mt-3 text-sm text-slate-500") { exchange_payer_entity_transaction?(entity_transaction) ? "No exchange rows yet." : I18n.t("dashboards.empty") }
      end
    end
  end

  def exchange_row(exchange)
    href = exchange.cash_transaction.present? ? cash_transaction_path(exchange.cash_transaction) : nil
    row_classes = "grid grid-cols-12 items-center border-t border-slate-200 px-3 py-2 text-sm #{exchange_row_class(exchange)}"

    if href.present?
      link_to href, class: "#{row_classes} transition hover:brightness-95", data: { turbo_frame: "_top", turbo_prefetch: false } do
        exchange_row_content(exchange)
      end
    else
      div(class: row_classes) do
        exchange_row_content(exchange)
      end
    end
  end

  def exchange_mobile_card(exchange)
    href = exchange.cash_transaction.present? ? cash_transaction_path(exchange.cash_transaction) : nil
    classes = "rounded-xl border border-inherit px-3 py-2 #{exchange_row_class(exchange)}"

    if href.present?
      link_to href, class: "#{classes} block transition hover:brightness-95", data: { turbo_frame: "_top", turbo_prefetch: false } do
        exchange_mobile_card_content(exchange)
      end
    else
      div(class: classes) do
        exchange_mobile_card_content(exchange)
      end
    end
  end

  def exchange_mobile_card_content(exchange)
    div(class: "flex items-start gap-3") do
      p(class: "rounded-md border border-slate-300 bg-white/80 px-2 py-1 text-2xs font-black uppercase tracking-[0.16em] text-slate-700") do
        exchange.number
      end
    end

    div(class: "mt-3 grid grid-cols-3 gap-2") do
      compact_installment_stat(model_attribute(Exchange, :month_year), exchange.month_year)
      compact_installment_stat(model_attribute(CardInstallment, :date), localized_date(exchange.date))
      compact_installment_stat(model_attribute(Exchange, :price), money(exchange.price), emphasis: true)
    end
  end

  def exchange_row_content(exchange)
    span(class: "col-span-2 text-center font-bold text-slate-950") { exchange.number }
    span(class: "col-span-4 font-semibold text-slate-950") { exchange.month_year }
    span(class: "col-span-4 font-semibold text-slate-950") { localized_date(exchange.date) }
    span(class: "col-span-2 text-right font-bold text-slate-950") { money(exchange.price) }
  end

  def exchange_bound_badge(exchange)
    label = exchange.card_bound? ? "Card Bound" : "Standalone"
    classes = exchange.card_bound? ? "bg-sky-200 text-sky-950" : "bg-slate-200 text-slate-900"

    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{classes}") { label }
  end

  def exchange_entity_role_badge(entity_transaction)
    label = exchange_payer_entity_transaction?(entity_transaction) ? "Payer" : "Non-Payer"
    classes = exchange_payer_entity_transaction?(entity_transaction) ? "bg-amber-100 text-amber-900" : "bg-slate-100 text-slate-700"

    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{classes}") { label }
  end

  def exchange_entity_bound_badge(entity_transaction)
    exchange = entity_transaction.exchanges.first
    return if exchange.blank?

    exchange_bound_badge(exchange)
  end

  def exchange_entity_summary_badge(text)
    span(class: "rounded-full bg-slate-100 px-2.5 py-1 text-2xs font-bold uppercase tracking-[0.16em] text-slate-700") { text }
  end

  def exchange_entity_summary_text(entity_transaction)
    if exchange_payer_entity_transaction?(entity_transaction)
      "#{money(entity_transaction.price_to_be_returned)} · #{entity_transaction.exchanges_count}x"
    else
      money(entity_transaction.price)
    end
  end

  def exchange_row_class(exchange)
    exchange.cash_transaction&.paid? ? "bg-emerald-50" : "bg-rose-50"
  end

  def invoice_link_item(cash_transaction)
    link_to cash_transaction_path(cash_transaction),
            class: "block rounded-2xl border border-sky-200 bg-sky-50/80 px-4 py-3 transition hover:border-sky-500 hover:bg-sky-100",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      div(class: "flex") do
        span(class: "mt-1 truncate text-sm font-bold text-slate-950") { cash_transaction.description }
      end

      div(class: "mt-3 flex items-center justify-between border-t border-sky-200 pt-2 text-2xs font-bold uppercase tracking-[0.16em] text-sky-800") do
        span { localized_date(cash_transaction.date) }
        p(class: "text-sm font-black text-sky-900") { money(cash_transaction.price) }
      end
    end
  end

  def invoice_row(cash_transaction, number, total_count)
    link_to cash_transaction_path(cash_transaction),
            class: "grid grid-cols-12 items-center border-t px-4 py-3 text-sm transition #{invoice_row_class(cash_transaction)}",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      span(class: "col-span-2 text-center font-bold text-slate-950") { pretty_installments(number, total_count) }
      span(class: "col-span-3 font-semibold text-slate-950") { cash_transaction.month_year }
      span(class: "col-span-3 font-semibold text-slate-950") { localized_date(cash_transaction.date) }
      span(class: "col-span-2 text-right font-bold text-slate-950") { money(cash_transaction.price) }
      span(class: "col-span-2 flex justify-end") { invoice_status_badge(cash_transaction) }
    end
  end

  def combined_mobile_installment_content(installment, cash_transaction)
    div(class: "p-3") do
      div(class: "flex items-center justify-between gap-3") do
        p(class: "inline-flex rounded-md border border-slate-300 bg-white/85 px-2 py-1 text-2xs font-black uppercase tracking-[0.16em] text-slate-700") do
          pretty_installments(installment.number, installment.card_installments_count)
        end

        installment_status_badge(installment)

        p(class: "text-sm font-bold text-slate-950") { installment.month_year }
      end

      hr(class: "my-3 border-slate-300")

      div(class: "grid grid-cols-2 gap-3") do
        div(class: "rounded-lg border border-inherit px-3 py-2 text-left") do
          compact_installment_stat(model_attribute(CardInstallment, :date), localized_date(installment.date))
          div(class: "mt-2") do
            compact_installment_stat(model_attribute(CardInstallment, :price), money(installment.price), emphasis: true)
          end
        end

        if cash_transaction.present?
          link_to cash_transaction_path(cash_transaction),
                  class: "block rounded-lg border border-sky-300 bg-sky-50 px-3 py-2 text-right transition hover:border-sky-500 hover:bg-sky-100",
                  data: { turbo_frame: "_top", turbo_prefetch: false } do
            compact_invoice_stat(model_attribute(CashTransaction, :date), localized_date(cash_transaction.date))
            div(class: "mt-2") do
              compact_invoice_stat(model_attribute(CashTransaction, :price), money(cash_transaction.price), emphasis: true)
            end
          end
        else
          div(class: "rounded-lg border border-slate-200 bg-white/80 px-3 py-2 text-right") do
            compact_invoice_stat(model_attribute(CashTransaction, :date), "-")
            div(class: "mt-2") do
              compact_invoice_stat(model_attribute(CashTransaction, :price), "-", emphasis: true)
            end
          end
        end
      end
    end
  end

  def compact_invoice_stat(label, value, emphasis: false)
    div do
      p(class: "text-2xs font-bold uppercase tracking-[0.16em] text-sky-700") { label }
      p(class: "#{emphasis ? 'text-sm' : 'text-xs'} mt-1 font-bold text-slate-950") { value }
    end
  end

  def reference_link_item
    reference = dashboard_reference
    return if reference.blank?

    link_item(I18n.t("dashboards.card_transactions.reference"), reference.description, reference_path_for(reference))
  end

  def descendants_link_item
    return if reference_descendants.empty?

    p(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700") do
      I18n.t("dashboards.card_transactions.reference_descendants", count: reference_descendants.count)
    end
  end

  def render_pay_in_advance_modal
    return unless pay_in_advance_available?

    render Views::CardTransactions::PayInAdvanceModal.new(
      month: card_transaction.month,
      year: card_transaction.year,
      user_card_id: card_transaction.user_card_id,
      min_date: pay_in_advance_min_date,
      max_date: pay_in_advance_max_date
    )
  end

  def installments
    @installments ||= card_transaction.card_installments.order(:number, :date).to_a
  end

  def invoice_cash_transactions
    @invoice_cash_transactions ||= installments.filter_map(&:cash_transaction).uniq
  end

  def categories
    @categories ||= card_transaction.categories.order(:category_name).to_a
  end

  def entities
    @entities ||= card_transaction.entities.order(:entity_name).to_a
  end

  def exchange_entity_transactions
    @exchange_entity_transactions ||= card_transaction.entity_transactions.includes(:entity, exchanges: :cash_transaction).sort_by do |entity_transaction|
      [ exchange_payer_entity_transaction?(entity_transaction) ? 0 : 1, entity_transaction.entity.entity_name ]
    end
  end

  def exchange_payer_entity_transaction?(entity_transaction)
    return true if entity_transaction.is_payer?
    return false if entity_transaction.price.to_i.zero?

    entity_transaction.entity.entity_name == "MOI"
  end

  def reference_descendants
    @reference_descendants ||= [
      *current_context.card_transactions.where(reference_transactable: card_transaction).order(:created_at, :id).to_a,
      *current_context.cash_transactions.where(reference_transactable: card_transaction).order(:created_at, :id).to_a
    ]
  end

  def dashboard_reference
    @dashboard_reference ||= begin
      reference = card_transaction.reference_transactable
      reference if visible_dashboard_reference?(reference)
    end
  end

  def visible_dashboard_reference?(reference)
    case reference
    when CashTransaction then current_context.cash_transactions.exists?(id: reference.id)
    when CardTransaction then current_context.card_transactions.exists?(id: reference.id)
    when Budget then current_context.budgets.exists?(id: reference.id)
    else false
    end
  end

  def dashboard_links_empty?
    card_transaction.subscription.blank? &&
      card_transaction.advance_cash_transaction.blank? &&
      dashboard_reference.blank? &&
      reference_descendants.empty?
  end

  def duplicate_allowed?
    card_transaction.can_be_destroyed? && !card_transaction.card_advance_category?
  end

  def pay_in_advance_available?
    return false if card_transaction.card_advance_category?
    return false if invoice_cash_transactions.empty?

    !invoice_cash_transactions.first.paid?
  end

  def pay_in_advance_modal_id
    "cardTransactionModal_#{card_transaction.user_card_id}_#{card_transaction.month}_#{card_transaction.year}"
  end

  def pay_in_advance_min_date
    @pay_in_advance_min_date ||= begin
      previous_reference = card_transaction.user_card.references.find_by_month_year(month_year_date - 1.month)&.reference_closing_date
      previous_reference&.to_datetime&.strftime("%Y-%m-%dT%H:%M")
    end
  end

  def pay_in_advance_max_date
    @pay_in_advance_max_date ||= begin
      current_reference = card_transaction.user_card.references.find_by_month_year(month_year_date)&.reference_date
      current_reference&.to_datetime&.strftime("%Y-%m-%dT%H:%M")
    end
  end

  def month_year_date
    Date.new(card_transaction.year, card_transaction.month, 1)
  end

  def special_labels
    [
      (I18n.t("naming_conventions.conventions.card_advance") if card_transaction.card_advance_category?),
      (model_attribute(CardTransaction, :subscription_id) if card_transaction.subscription.present?)
    ].compact
  end

  def reference_path_for(reference)
    case reference
    when CashTransaction then cash_transaction_path(reference)
    when CardTransaction then card_transaction_path(reference)
    when Budget then budget_path(reference)
    else "#"
    end
  end

  def paid_state_label
    return I18n.t("filters.paid_state.paid") if installments.all?(&:paid?)
    return I18n.t("dashboards.status.partial") if installments.any?(&:paid?)

    I18n.t("filters.paid_state.pending")
  end

  def paid_state_class
    return "bg-emerald-100 text-emerald-900" if installments.all?(&:paid?)
    return "bg-amber-100 text-amber-900" if installments.any?(&:paid?)

    "bg-rose-100 text-rose-900"
  end

  def paid_label(installment)
    installment.paid? ? I18n.t("filters.paid_state.paid") : I18n.t("filters.paid_state.pending")
  end

  def installment_row_class(installment)
    if installment.paid?
      "border-emerald-200 bg-emerald-50 text-emerald-950"
    else
      "border-rose-200 bg-rose-50 text-rose-950"
    end
  end

  def installment_mobile_card_class(installment)
    installment.paid? ? "border-emerald-200 bg-emerald-50" : "border-rose-200 bg-rose-50"
  end

  def installment_status_badge(installment)
    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{installment_status_badge_class(installment)}") do
      paid_label(installment)
    end
  end

  def installment_status_badge_class(installment)
    installment.paid? ? "bg-emerald-200 text-emerald-950" : "bg-rose-200 text-rose-950"
  end

  def invoice_row_class(cash_transaction)
    if cash_transaction.paid?
      "border-emerald-200 bg-emerald-50 text-emerald-950 hover:bg-emerald-100"
    else
      "border-rose-200 bg-rose-50 text-rose-950 hover:bg-rose-100"
    end
  end

  def invoice_status_badge(cash_transaction)
    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{invoice_status_badge_class(cash_transaction)}") do
      cash_transaction.paid? ? I18n.t("filters.paid_state.paid") : I18n.t("filters.paid_state.pending")
    end
  end

  def invoice_status_badge_class(cash_transaction)
    cash_transaction.paid? ? "bg-emerald-200 text-emerald-950" : "bg-rose-200 text-rose-950"
  end

  def compact_installment_stat(label, value, emphasis: false)
    div do
      p(class: "text-2xs font-bold uppercase tracking-[0.16em] text-slate-500") { label }
      p(class: "#{emphasis ? 'text-sm' : 'text-xs'} mt-1 font-bold text-slate-950") { value }
    end
  end

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end

  def empty_state_card
    div(class: "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-6 text-center text-sm text-slate-500") do
      I18n.t("dashboards.empty")
    end
  end

  def card_name
    card_transaction.user_card&.user_card_name || "-"
  end

  def localized_date(value)
    I18n.l(value, format: :short)
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end
end
