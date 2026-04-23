# frozen_string_literal: true

class Views::Budgets::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :budget

  def initialize(budget:)
    @budget = budget
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "min-h-[calc(100svh-12rem)] rounded-3xl border border-slate-200 bg-white p-4 shadow-sm sm:p-6") do
        dashboard_header

        div(class: "mt-6 grid gap-4 xl:grid-cols-[1.35fr_0.65fr]") do
          div(class: "space-y-4") do
            summary_grid
            consumption_section
          end

          div(class: "space-y-4") do
            definition_section
            allocations_section
          end
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-left text-4xl font-black tracking-tight text-slate-950") { budget.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          rule_badges
        end
      end

      div(class: "flex flex-wrap gap-2 lg:justify-end") do
        dashboard_action(action_model(:edit, Budget), edit_budget_path(budget), variant: :outline)
        destroy_action
        dashboard_action(action_model(:index, Budget, 2), budget_index_path, variant: :primary)
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 md:grid-cols-2 xl:grid-cols-5") do
        dashboard_stat(model_attribute(Budget, :value), money(budget.value), emphasis: true)
        dashboard_stat(I18n.t("dashboards.budgets.consumed"), money(consumed_amount), emphasis: true)
        dashboard_stat(model_attribute(Budget, :remaining_value), money(budget.remaining_value), emphasis: true)
        dashboard_stat(model_attribute(Budget, :balance), money(budget.balance))
        dashboard_stat(model_attribute(Budget, :month_year), I18n.l(budget.date, format: "%B %Y"))
      end
    end
  end

  def consumption_section
    section_card(I18n.t("dashboards.budgets.consumption")) do
      if matched_installments.present?
        div(class: "overflow-hidden rounded-2xl border border-slate-200") do
          div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
            span(class: "col-span-2") { I18n.t("dashboards.budgets.source") }
            span(class: "col-span-2") { model_attribute(CashInstallment, :date) }
            span(class: "col-span-3") { model_attribute(CashTransaction, :description) }
            span(class: "col-span-2 text-center") { model_attribute(CashInstallment, :number) }
            span(class: "col-span-2 text-right") { model_attribute(CashInstallment, :price) }
            span(class: "col-span-1 text-right") { model_attribute(CashInstallment, :paid) }
          end

          matched_installments.each do |installment|
            installment_row(installment)
          end
        end
      else
        empty_state
      end
    end
  end

  def definition_section
    section_card(I18n.t("dashboards.budgets.definition")) do
      div(class: "grid gap-3 sm:grid-cols-2") do
        dashboard_stat(model_attribute(Budget, :starting_value), money(budget.starting_value))
        dashboard_stat(model_attribute(Budget, :active), boolean_label(budget.active?))
        dashboard_stat(model_attribute(Budget, :inclusive), boolean_label(budget.inclusive?))
        dashboard_stat(model_attribute(Budget, :first_installment_only), boolean_label(budget.first_installment_only?))
      end
    end
  end

  def allocations_section
    section_card(I18n.t("dashboards.sections.allocations")) do
      allocation_group(model_attribute(Budget, :categories), categories.map(&:name))
      allocation_group(model_attribute(Budget, :entities), entities.map(&:entity_name))
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
    transaction = installment.transactable

    link_to dashboard_path_for(transaction),
            class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm text-slate-700 transition hover:bg-slate-50",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      span(class: "col-span-2 font-semibold text-slate-950") { source_label(transaction) }
      span(class: "col-span-2") { localized_date(installment.date) }
      span(class: "col-span-3 truncate", title: transaction.description) { transaction.description }
      span(class: "col-span-2 text-center") { pretty_installments(installment.number, installment_count_for(installment)) }
      span(class: "col-span-2 text-right font-bold") { money(installment.price) }
      span(class: "col-span-1 text-right") { paid_label(installment) }
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
    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{status_class}") do
      status_label
    end
  end

  def rule_badges
    [ rule_label(:inclusive, budget.inclusive?), rule_label(:first_installment_only, budget.first_installment_only?) ].each do |label|
      span(class: "rounded-full border border-amber-300 bg-amber-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-amber-900") { label }
    end
  end

  def dashboard_action(label, href, variant:)
    link_to label,
            href,
            class: dashboard_action_class(variant),
            data: { turbo_frame: "_top", turbo_prefetch: false }
  end

  def destroy_action
    LinkWithConfirmation(
      id: budget.id,
      text: action_message(:destroy),
      link_params: {
        href: budget_path(budget),
        id: "delete_budget_#{budget.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
      }
    )
  end

  def dashboard_action_class(variant)
    base_class = "rounded-full px-4 py-2 text-sm font-semibold transition"

    case variant
    when :primary then "#{base_class} bg-slate-900 text-white hover:bg-slate-700"
    when :destroy then "#{base_class} bg-red-600 text-white hover:bg-red-700"
    else "#{base_class} border border-slate-300 text-slate-700 hover:bg-slate-100"
    end
  end

  def budget_index_path
    budgets_path(
      default_year: budget.year,
      active_month_years: active_month_years_param(budget.year, budget.month),
      budget: {
        category_id: categories.map(&:id),
        entity_id: entities.map(&:id)
      }.compact_blank
    )
  end

  def active_month_years_param(year, month)
    [ Date.new(year, month, 1).strftime("%Y%m").to_i ].to_json
  end

  def matched_installments
    @matched_installments ||= (matched_cash_installments + matched_card_installments).sort_by { |installment| [ installment.date, installment.id ] }
  end

  def matched_cash_installments
    @matched_cash_installments ||= filtered_installments(
      budget.context.cash_installments.includes(cash_transaction: %i[user_bank_account categories entities]).where(month: budget.month, year: budget.year),
      :cash
    ).to_a
  end

  def matched_card_installments
    @matched_card_installments ||= filtered_installments(
      budget.context.card_installments.includes(card_transaction: %i[user_card categories entities]).where(month: budget.month, year: budget.year),
      :card
    ).to_a
  end

  def filtered_installments(scope, kind)
    scope = scope.where(number: 1) if budget.first_installment_only?

    category_ids = categories.map(&:id)
    entity_ids = entities.map(&:id)

    if budget.inclusive? && category_ids.present? && entity_ids.present?
      scope.by_categories_and_entities(category_ids, entity_ids)
    elsif category_ids.present? && entity_ids.present?
      scope.by_categories_or_entities(category_ids, entity_ids)
    elsif category_ids.present?
      scope.by_categories(category_ids)
    elsif entity_ids.present?
      scope.by_entities(entity_ids)
    else
      kind == :cash ? CashInstallment.none : CardInstallment.none
    end
  end

  def categories
    @categories ||= budget.categories.order(:category_name).to_a
  end

  def entities
    @entities ||= budget.entities.order(:entity_name).to_a
  end

  def consumed_amount
    budget.value - budget.remaining_value
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end

  def localized_date(date)
    I18n.l(date.to_date, format: :long).upcase
  end

  def paid_label(installment)
    model_attribute(CashInstallment, installment.paid? ? :paid : :not_paid)
  end

  def status_label
    return I18n.t("dashboards.budgets.status.exceeded") if budget.remaining_value.negative?
    return I18n.t("dashboards.budgets.status.exact") if budget.remaining_value.zero?

    I18n.t("dashboards.budgets.status.available")
  end

  def status_class
    return "bg-red-100 text-red-800" if budget.remaining_value.negative?
    return "bg-amber-100 text-amber-900" if budget.remaining_value.zero?

    "bg-emerald-100 text-emerald-800"
  end

  def rule_label(rule, enabled)
    I18n.t("dashboards.budgets.rules.#{rule}.#{enabled ? 'enabled' : 'disabled'}")
  end

  def boolean_label(value)
    I18n.t("dashboards.budgets.boolean.#{value ? 'yes' : 'no'}")
  end

  def source_label(transaction)
    case transaction
    when CashTransaction then transaction.user_bank_account&.user_bank_account_name || CashTransaction.model_name.human
    when CardTransaction then transaction.user_card&.user_card_name || CardTransaction.model_name.human
    end
  end

  def installment_count_for(installment)
    case installment
    when CashInstallment then installment.cash_installments_count
    when CardInstallment then installment.card_installments_count
    end
  end

  def dashboard_path_for(transaction)
    case transaction
    when CashTransaction then cash_transaction_path(transaction)
    when CardTransaction then card_transaction_path(transaction)
    end
  end

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end
end
