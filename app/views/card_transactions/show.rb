# frozen_string_literal: true

class Views::CardTransactions::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :card_transaction

  def initialize(card_transaction:)
    @card_transaction = card_transaction
  end

  def view_template
    render_pay_in_advance_modal

    turbo_frame_tag :center_container do
      div(class: "min-h-[calc(100svh-12rem)] rounded-3xl border border-slate-200 bg-white p-4 shadow-sm sm:p-6") do
        dashboard_header

        div(class: "mt-6 grid gap-4 xl:grid-cols-[1.35fr_0.65fr]") do
          div(class: "space-y-4") do
            summary_grid
            installments_section
            invoice_section
          end

          div(class: "space-y-4") do
            allocations_section
            links_section
            exchanges_section
          end
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0") do
        h1(class: "text-4xl font-black tracking-tight text-slate-950") { card_transaction.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          special_badges
        end

        p(class: "mt-3 max-w-3xl text-sm leading-6 text-slate-600") { card_transaction.comment } if card_transaction.comment.present?
      end

      div(class: "flex flex-wrap gap-2 lg:justify-end") do
        dashboard_action(action_model(:edit, CardTransaction), edit_card_transaction_path(card_transaction), variant: :outline)
        dashboard_action(action_message(:duplicate), duplicate_card_transaction_path(card_transaction), variant: :outline) if duplicate_allowed?
        pay_in_advance_action
        destroy_action
        dashboard_action(action_model(:index, CardTransaction, 2), card_index_path, variant: :primary)
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 md:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(CardTransaction, :price), money(card_transaction.price), emphasis: true)
        dashboard_stat(model_attribute(CardTransaction, :date), localized_date(card_transaction.date))
        dashboard_stat(model_attribute(CardTransaction, :month), I18n.l(Date.new(card_transaction.year, card_transaction.month, 1), format: "%B %Y"))
        dashboard_stat(model_attribute(CardTransaction, :user_card_id), card_name)
      end
    end
  end

  def installments_section
    section_card(I18n.t("dashboards.sections.installments")) do
      div(class: "overflow-hidden rounded-2xl border border-slate-200") do
        div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
          span(class: "col-span-3") { model_attribute(CardInstallment, :date) }
          span(class: "col-span-2 text-center") { model_attribute(CardInstallment, :number) }
          span(class: "col-span-3 text-right") { model_attribute(CardInstallment, :price) }
          span(class: "col-span-2 text-right") { model_attribute(CardInstallment, :paid) }
          span(class: "col-span-2 text-right") { model_attribute(CashTransaction, :user_bank_account_id) }
        end

        installments.each do |installment|
          installment_row(installment)
        end
      end
    end
  end

  def invoice_section
    section_card(I18n.t("dashboards.card_transactions.invoice")) do
      if invoice_cash_transactions.present?
        div(class: "space-y-2") do
          invoice_cash_transactions.each do |cash_transaction|
            link_item(cash_transaction.description, money(cash_transaction.price), cash_transaction_path(cash_transaction))
          end
        end
      else
        empty_state
      end
    end
  end

  def allocations_section
    section_card(I18n.t("dashboards.sections.allocations")) do
      allocation_group(model_attribute(CardTransaction, :categories), categories.map(&:name))
      allocation_group(model_attribute(CardTransaction, :entities), entities.map(&:entity_name))
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
      if exchanges.present?
        div(class: "space-y-2") do
          exchanges.each do |exchange|
            exchange_item(exchange)
          end
        end
      else
        empty_state
      end
    end
  end

  def section_card(title, &)
    section(class: "rounded-3xl border border-slate-200 bg-slate-50/80 p-4") do
      h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500") { title }
      div(class: "mt-4", &)
    end
  end

  def dashboard_stat(label, value, emphasis: false)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "#{emphasis ? 'text-2xl' : 'text-lg'} mt-2 font-bold text-slate-950") { value.to_s }
    end
  end

  def installment_row(installment)
    div(class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm text-slate-700") do
      span(class: "col-span-3 font-semibold text-slate-950") { localized_date(installment.date) }
      span(class: "col-span-2 text-center") { pretty_installments(installment.number, installment.card_installments_count) }
      span(class: "col-span-3 text-right font-bold") { money(installment.price) }
      span(class: "col-span-2 text-right") { paid_label(installment) }
      span(class: "col-span-2 truncate text-right", title: installment.cash_transaction&.user_bank_account&.user_bank_account_name) do
        installment.cash_transaction&.user_bank_account&.user_bank_account_name || "-"
      end
    end
  end

  def allocation_group(label, names)
    div(class: "mb-4 last:mb-0") do
      p(class: "text-2xs font-bold uppercase tracking-[0.18em] text-slate-500") { label }

      if names.present?
        div(class: "mt-2 flex flex-wrap gap-2") do
          names.each do |name|
            span(class: "rounded-full border border-slate-300 bg-white px-3 py-1 text-xs font-semibold text-slate-800", title: name) { name }
          end
        end
      else
        empty_state
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
    link_to label,
            href,
            class: dashboard_action_class(variant),
            data: { turbo_frame: "_top", turbo_prefetch: false }
  end

  def pay_in_advance_action
    return unless pay_in_advance_available?

    button(
      type: :button,
      class: dashboard_action_class(:pay),
      data: { modal_target: pay_in_advance_modal_id, modal_toggle: pay_in_advance_modal_id }
    ) do
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
        variant: :ghost,
        id: "delete_card_transaction_#{card_transaction.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
      }
    )
  end

  def dashboard_action_class(variant)
    base_class = "rounded-full px-4 py-2 text-sm font-semibold transition"

    case variant
    when :primary then "#{base_class} bg-slate-900 text-white hover:bg-slate-700"
    when :pay then "#{base_class} bg-money text-white hover:opacity-80"
    when :destroy then "#{base_class} bg-red-600 text-white hover:bg-red-700"
    else "#{base_class} border border-slate-300 text-slate-700 hover:bg-slate-100"
    end
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
    link_to href, class: "block rounded-2xl border border-slate-200 bg-white px-4 py-3 transition hover:border-slate-400",
                  data: { turbo_frame: "_top", turbo_prefetch: false } do
      p(class: "text-2xs font-bold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "mt-1 truncate text-sm font-bold text-slate-950") { value }
    end
  end

  def exchange_item(exchange)
    href = exchange.cash_transaction.present? ? cash_transaction_path(exchange.cash_transaction) : "#"
    link_item(exchange.exchange_type.to_s.humanize, "#{money(exchange.price)} - #{localized_date(exchange.date)}", href)
  end

  def reference_link_item
    reference = card_transaction.reference_transactable
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

    render Views::CardTransactions::PayInAdvanceModal.new(month: card_transaction.month, year: card_transaction.year, user_card_id: card_transaction.user_card_id,
                                                          min_date: pay_in_advance_min_date, max_date: pay_in_advance_max_date)
  end

  def installments
    @installments ||= card_transaction.card_installments.includes(cash_transaction: :user_bank_account).order(:number, :date).to_a
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

  def exchanges
    @exchanges ||= card_transaction.entity_transactions.includes(exchanges: :cash_transaction).flat_map(&:exchanges).sort_by do |exchange|
      [ exchange.date || Time.zone.at(0), exchange.id || 0 ]
    end
  end

  def reference_descendants
    @reference_descendants ||= [
      *current_context.card_transactions.where(reference_transactable: card_transaction).order(:created_at, :id).to_a,
      *current_context.cash_transactions.where(reference_transactable: card_transaction).order(:created_at, :id).to_a
    ]
  end

  def dashboard_links_empty?
    card_transaction.subscription.blank? &&
      card_transaction.advance_cash_transaction.blank? &&
      card_transaction.reference_transactable.blank? &&
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

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
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
