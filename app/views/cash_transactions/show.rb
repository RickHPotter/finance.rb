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
      div(class: "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm sm:rounded-3xl sm:p-6") do
        dashboard_header

        if mobile?
          div(class: "mt-6 space-y-4") do
            summary_grid
            allocations_section
            links_section
            installments_section
          end
        else
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
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 sm:text-4xl") { cash_transaction.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          special_badges
        end

        p(class: "mt-3 max-w-3xl text-sm leading-6 text-slate-600") { cash_transaction.comment } if cash_transaction.comment.present?
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(action_message(:edit), edit_cash_transaction_path(cash_transaction), variant: :edit)
        dashboard_action(action_message(:duplicate), duplicate_cash_transaction_path(cash_transaction), variant: :duplicate) if duplicate_allowed?
        pay_action_button
        destroy_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(CashTransaction, :price), money(cash_transaction.price), emphasis: true)
        dashboard_stat(model_attribute(CashTransaction, :date), localized_date(cash_transaction.date))
        dashboard_stat(model_attribute(CashTransaction, :month), I18n.l(cash_transaction.date, format: "%B %Y"))
        dashboard_stat(model_attribute(CashTransaction, :user_bank_account_id), account_name)
      end
    end
  end

  def installments_section
    section_card(I18n.t("dashboards.sections.installments")) do
      if mobile?
        div(class: "space-y-3") do
          installments.each do |installment|
            installment_mobile_card(installment)
          end
        end
      else
        div(class: "overflow-hidden rounded-2xl border border-slate-200") do
          div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
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
    div(class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm text-slate-700") do
      span(class: "col-span-3 font-semibold text-slate-950") { localized_date(installment.date) }
      span(class: "col-span-2 text-center") { pretty_installments(installment.number, installment.cash_installments_count) }
      span(class: "col-span-3 text-right font-bold") { money(installment.price) }
      span(class: "col-span-2 text-right font-bold") { money(installment.balance) }
      span(class: "col-span-2 text-right") { paid_label(installment) }
    end
  end

  def installment_mobile_card(installment)
    div(class: "rounded-2xl border border-slate-200 bg-white p-4") do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          p(class: "text-2xs font-bold uppercase tracking-[0.18em] text-slate-500") { model_attribute(CashInstallment, :date) }
          p(class: "mt-1 text-sm font-bold text-slate-950") { localized_date(installment.date) }
        end

        span(class: "rounded-full bg-slate-100 px-3 py-1 text-2xs font-bold uppercase tracking-[0.16em] text-slate-700") do
          pretty_installments(installment.number, installment.cash_installments_count)
        end
      end

      div(class: "mt-4 grid grid-cols-2 gap-3") do
        mobile_stat(model_attribute(CashInstallment, :price), money(installment.price))
        mobile_stat(model_attribute(CashInstallment, :balance), money(installment.balance))
        mobile_stat(model_attribute(CashInstallment, :paid), paid_label(installment))
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
    Button(link: href, variant: dashboard_action_variant(variant), class: dashboard_action_class(variant), data: { turbo_frame: "_top", turbo_prefetch: false }) do
      label
    end
  end

  def pay_action_button
    return if payable_installment.blank?

    Button(type: :button, variant: dashboard_action_variant(:pay), class: dashboard_action_class(:pay),
           data: { modal_target: "cashInstallmentModal_#{payable_installment.id}", modal_toggle: "cashInstallmentModal_#{payable_installment.id}" }) do
      model_attribute(payable_installment, :pay)
    end
  end

  def destroy_action
    return unless cash_transaction.can_be_destroyed?

    LinkWithConfirmation(
      id: "cash_transaction_dashboard_destroy_#{cash_transaction.id}",
      text: action_message(:destroy),
      link_params: {
        href: cash_transaction_path(cash_transaction),
        variant: :destructive,
        id: "delete_cash_transaction_#{cash_transaction.id}",
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

  def cash_index_path
    cash_transactions_path(
      default_year: cash_transaction.year,
      active_month_years: active_month_years_param(cash_transaction.year, cash_transaction.month),
      cash_transaction: { user_bank_account_id: cash_transaction.user_bank_account_id }
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

  def reference_link_item
    reference = dashboard_reference
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

  def dashboard_reference
    @dashboard_reference ||= begin
      reference = cash_transaction.reference_transactable
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

  def payable_installment
    @payable_installment ||= installments.reject(&:paid?).one? ? installments.reject(&:paid?).first : nil
  end

  def dashboard_links_empty?
    cash_transaction.subscription.blank? &&
      dashboard_reference.blank? &&
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
