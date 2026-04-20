# frozen_string_literal: true

class Views::CashTransactions::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :cash_transaction

  def initialize(cash_transaction:)
    @cash_transaction = cash_transaction
  end

  def view_template
    render_pay_modal

    turbo_frame_tag :center_container do
      div(class: "min-h-[calc(100svh-12rem)] rounded-3xl border border-slate-200 bg-white p-4 shadow-sm sm:p-6") do
        dashboard_header

        div(class: "mt-6 grid gap-4 xl:grid-cols-[1.35fr_0.65fr]") do
          div(class: "space-y-4") do
            summary_grid
            installments_section
          end

          div(class: "space-y-4") do
            allocations_section
            links_section
          end
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase tracking-[0.22em] text-slate-500") { action_model(:analyse, CashTransaction) }
        h1(class: "mt-2 text-3xl font-black tracking-tight text-slate-950") { cash_transaction.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          special_badges
        end

        p(class: "mt-3 max-w-3xl text-sm leading-6 text-slate-600") { cash_transaction.comment } if cash_transaction.comment.present?
      end

      div(class: "flex flex-wrap gap-2 lg:justify-end") do
        dashboard_action(action_model(:edit, CashTransaction), edit_cash_transaction_path(cash_transaction), variant: :outline)
        dashboard_action(action_message(:duplicate), duplicate_cash_transaction_path(cash_transaction), variant: :outline) if duplicate_allowed?
        pay_action_button
        destroy_action
        dashboard_action(action_model(:index, CashTransaction, 2), cash_transactions_path, variant: :primary)
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 md:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(CashTransaction, :price), money(cash_transaction.price), emphasis: true)
        dashboard_stat(model_attribute(CashTransaction, :date), localized_date(cash_transaction.date))
        dashboard_stat(model_attribute(CashTransaction, :month), I18n.l(cash_transaction.date, format: "%B %Y"))
        dashboard_stat(model_attribute(CashTransaction, :user_bank_account_id), account_name)
      end
    end
  end

  def installments_section
    section_card(I18n.t("dashboards.sections.installments")) do
      div(class: "overflow-hidden rounded-2xl border border-slate-200") do
        div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-[10px] font-bold uppercase tracking-[0.18em] text-white") do
          span(class: "col-span-3") { model_attribute(CashInstallment, :date) }
          span(class: "col-span-2 text-center") { model_attribute(CashInstallment, :number) }
          span(class: "col-span-3 text-right") { model_attribute(CashInstallment, :price) }
          span(class: "col-span-2 text-right") { model_attribute(CashInstallment, :balance) }
          span(class: "col-span-2 text-right") { model_attribute(CashInstallment, :paid) }
        end

        installments.each do |installment|
          installment_row(installment)
        end
      end
    end
  end

  def allocations_section
    section_card(I18n.t("dashboards.sections.allocations")) do
      allocation_group(model_attribute(CashTransaction, :categories), categories.map(&:name))
      allocation_group(model_attribute(CashTransaction, :entities), entities.map(&:entity_name))
    end
  end

  def links_section
    section_card(I18n.t("dashboards.sections.links")) do
      div(class: "space-y-2") do
        if cash_transaction.subscription.present?
          link_item(model_attribute(CashTransaction, :subscription_id), cash_transaction.subscription&.description,
                    edit_subscription_path(cash_transaction.subscription))
        end
        reference_link_item
        descendants_link_item
        special_link_item
        empty_links_state if dashboard_links_empty?
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
      p(class: "text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "#{emphasis ? 'text-2xl' : 'text-lg'} mt-2 font-bold text-slate-950") { value.to_s }
    end
  end

  def installment_row(installment)
    div(class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm text-slate-700") do
      span(class: "col-span-3 font-semibold text-slate-950") { localized_date(installment.date) }
      span(class: "col-span-2 text-center") { pretty_installments(installment.number, installment.cash_installments_count) }
      span(class: "col-span-3 text-right font-bold") { money(installment.price) }
      span(class: "col-span-2 text-right font-bold") { money(installment.balance) }
      span(class: "col-span-2 text-right") { paid_label(installment) }
    end
  end

  def allocation_group(label, names)
    div(class: "mb-4 last:mb-0") do
      p(class: "text-[10px] font-bold uppercase tracking-[0.18em] text-slate-500") { label }

      if names.present?
        div(class: "mt-2 flex flex-wrap gap-2") do
          names.each do |name|
            span(class: "rounded-full border border-slate-300 bg-white px-3 py-1 text-xs font-semibold text-slate-800", title: name) { name }
          end
        end
      else
        p(class: "mt-2 text-sm text-slate-500") { I18n.t("dashboards.empty") }
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

  def pay_action_button
    return if payable_installment.blank?

    button(
      type: :button,
      class: dashboard_action_class(:pay),
      data: { modal_target: "cashInstallmentModal_#{payable_installment.id}", modal_toggle: "cashInstallmentModal_#{payable_installment.id}" }
    ) do
      model_attribute(payable_installment, :pay)
    end
  end

  def destroy_action
    return unless cash_transaction.can_be_destroyed?

    link_to action_message(:destroy),
            cash_transaction_path(cash_transaction),
            id: "delete_cash_transaction_#{cash_transaction.id}",
            class: dashboard_action_class(:destroy),
            data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure"), turbo_frame: "_top" }
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

  def link_item(label, value, href)
    link_to href, class: "block rounded-2xl border border-slate-200 bg-white px-4 py-3 transition hover:border-slate-400",
                  data: { turbo_frame: "_top", turbo_prefetch: false } do
      p(class: "text-[10px] font-bold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "mt-1 truncate text-sm font-bold text-slate-950") { value }
    end
  end

  def reference_link_item
    reference = cash_transaction.reference_transactable
    return if reference.blank?

    link_item(I18n.t("dashboards.cash_transactions.reference"), reference.description, reference_path_for(reference))
  end

  def descendants_link_item
    return if reference_descendants.empty?

    p(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700") do
      I18n.t("dashboards.cash_transactions.reference_descendants", count: reference_descendants.count)
    end
  end

  def special_link_item
    return unless cash_transaction.card_payment? || cash_transaction.card_advance? || cash_transaction.investment?

    p(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700") do
      special_labels.join(" · ")
    end
  end

  def empty_links_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end

  def render_pay_modal
    render Views::CashInstallments::PayModal.new(cash_installment: payable_installment) if payable_installment.present?
  end

  def installments
    @installments ||= cash_transaction.cash_installments.order(:number, :date).to_a
  end

  def categories
    @categories ||= cash_transaction.categories.order(:category_name).to_a
  end

  def entities
    @entities ||= cash_transaction.entities.order(:entity_name).to_a
  end

  def reference_descendants
    @reference_descendants ||= cash_transaction.reference_children(scope: current_context.cash_transactions).to_a
  end

  def payable_installment
    @payable_installment ||= installments.reject(&:paid?).one? ? installments.reject(&:paid?).first : nil
  end

  def dashboard_links_empty?
    cash_transaction.subscription.blank? &&
      cash_transaction.reference_transactable.blank? &&
      reference_descendants.empty? &&
      !cash_transaction.card_payment? &&
      !cash_transaction.card_advance? &&
      !cash_transaction.investment?
  end

  def duplicate_allowed?
    cash_transaction.can_be_destroyed?
  end

  def special_labels
    [
      (I18n.t("naming_conventions.conventions.investment") if cash_transaction.investment?),
      (I18n.t("naming_conventions.conventions.card_payment") if cash_transaction.card_payment?),
      (I18n.t("naming_conventions.conventions.card_advance") if cash_transaction.card_advance?),
      (I18n.t("naming_conventions.conventions.exchange_return") if cash_transaction.exchange_return?),
      (I18n.t("dashboards.cash_transactions.borrow_return") if cash_transaction.borrow_return?)
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

  def account_name
    cash_transaction.user_bank_account&.user_bank_account_name || "-"
  end

  def localized_date(value)
    I18n.l(value, format: :short)
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end
end
