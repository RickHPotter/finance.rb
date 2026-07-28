# frozen_string_literal: true

class Views::Budgets::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :budget

  def initialize(budget:)
    @budget = budget
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm sm:rounded-3xl sm:p-6") do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_grid
          definition_section
          consumption_section
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 sm:text-4xl") { budget.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          rule_badges
        end
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), record_audit_versions_path(item_type: "Budget", item_id: budget.id), variant: :outline)
        dashboard_action(action_message(:edit), edit_budget_path(budget), variant: :edit)
        dashboard_action(action_message(:duplicate), duplicate_budget_path(budget), variant: :duplicate)
        destroy_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-5") do
        dashboard_stat(model_attribute(Budget, :value), money(budget.value), emphasis: true)
        dashboard_stat(I18n.t("dashboards.budgets.consumed"), money(consumed_amount), emphasis: true)
        dashboard_stat(model_attribute(Budget, :remaining_value), money(budget.remaining_value), emphasis: true)
        dashboard_stat(model_attribute(Budget, :balance), money(budget.balance))
        dashboard_stat(model_attribute(Budget, :month_year), I18n.l(budget.date, format: "%B %Y"))
      end

      div(class: "mt-4 grid gap-3 border-t border-slate-200 pt-4 xl:grid-cols-2") do
        allocation_group(model_attribute(Budget, :categories), categories, &:category_name)
        allocation_group(model_attribute(Budget, :entities), entities, &:name)
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

  def consumption_section
    section_card(I18n.t("dashboards.budgets.consumption")) do
      if matched_installments.present?
        if mobile?
          div(class: "space-y-3") do
            matched_installments.each do |installment|
              installment_mobile_card(installment)
            end
          end
        else
          div(class: "overflow-hidden rounded-2xl border border-slate-200") do
            div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
              span(class: "col-span-1 text-center") { model_attribute(CashInstallment, :number) }
              span(class: "col-span-2") { I18n.t("dashboards.budgets.source") }
              span(class: "col-span-3") { model_attribute(CashTransaction, :description) }
              span(class: "col-span-2") { model_attribute(CashInstallment, :date) }
              span(class: "col-span-2 text-center") { model_attribute(CashInstallment, :paid) }
              span(class: "col-span-2 text-right") { model_attribute(CashInstallment, :price) }
            end

            matched_installments.each do |installment|
              installment_row(installment)
            end
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
    transaction = installment.transactable

    link_to dashboard_path_for(transaction),
            class: "grid grid-cols-12 items-center border-t px-4 py-3 text-sm transition #{installment_row_class(installment)}",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      span(class: "col-span-1 text-center") { pretty_installments(installment.number, installment_count_for(installment)) }
      span(class: "col-span-2 font-semibold text-slate-950") { source_label(transaction) }
      span(class: "col-span-3 truncate font-semibold text-slate-950", title: transaction.description) { transaction.description }
      span(class: "col-span-2 text-slate-700") { localized_date(installment.date) }
      span(class: "col-span-2 flex justify-center") { installment_status_badge(installment) }
      span(class: "col-span-2 text-right font-bold") { money(installment.price) }
    end
  end

  def installment_mobile_card(installment)
    transaction = installment.transactable

    link_to dashboard_path_for(transaction),
            class: "block overflow-hidden rounded-xl border transition #{installment_mobile_card_class(installment)}",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      div(class: "p-3") do
        div(class: "grid grid-cols-3 items-center gap-3") do
          div(class: "flex justify-start") do
            p(class: "inline-flex rounded-md border border-slate-300 bg-white px-2 py-1 text-2xs font-black uppercase tracking-[0.16em] text-slate-700") do
              pretty_installments(installment.number, installment_count_for(installment))
            end
          end

          div(class: "flex justify-center") do
            installment_status_badge(installment)
          end

          p(class: "text-right text-sm font-bold text-slate-950") { localized_date(installment.date) }
        end

        hr(class: "my-3 border-slate-300")

        p(class: "text-center text-sm font-semibold text-slate-800", title: transaction.description) { transaction.description }

        hr(class: "my-3 border-slate-200")

        div(class: "grid grid-cols-2 gap-3") do
          div(class: "rounded-lg border border-slate-200 px-3 py-2 text-left") do
            mobile_split_stat(I18n.t("dashboards.budgets.source"), source_label(transaction))
          end

          div(class: "rounded-lg border border-slate-200 px-3 py-2 text-right") do
            mobile_split_stat(model_attribute(CashInstallment, :price), money(installment.price), emphasis: true)
          end
        end
      end
    end
  end

  def mobile_split_stat(label, value, emphasis: false)
    div do
      p(class: "text-2xs font-bold uppercase tracking-[0.16em] text-slate-500") { label }
      p(class: "#{emphasis ? 'text-sm' : 'text-xs'} mt-1 font-bold text-slate-950") { value }
    end
  end

  def allocation_group(label, records)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500") { label }

      if records.empty?
        p(class: "mt-2 text-sm text-slate-500") { I18n.t("dashboards.empty") }
      else
        div(class: "mt-3 flex flex-wrap justify-center gap-2") do
          if label == model_attribute(Budget, :categories)
            records.each do |category|
              span(
                class: "flex min-h-12 items-center justify-center break-words rounded-sm border border-black px-2 py-1 text-center text-sm text-black",
                style: "background: #{category.hex_colour}",
                title: category.category_name
              ) { category.category_name }
            end
          else
            records.each do |entity|
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
    Button(link: href, variant: dashboard_action_variant(variant), class: dashboard_action_class(variant), data: { turbo_frame: "_top", turbo_prefetch: false }) do
      label
    end
  end

  def destroy_action
    LinkWithConfirmation(
      id: budget.id,
      text: action_message(:destroy),
      link_params: {
        href: budget_path(budget),
        variant: :destructive,
        id: "delete_budget_#{budget.id}",
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
    when :destroy then "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white"
    else default
    end
  end

  def dashboard_action_variant(variant)
    return :purple if variant == :edit

    :outline
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
      budget.context.cash_installments.includes(cash_transaction: :user_bank_account).where(month: budget.month, year: budget.year),
      :cash
    ).to_a
  end

  def matched_card_installments
    @matched_card_installments ||= filtered_installments(
      budget.context.card_installments.includes(card_transaction: :user_card).where(month: budget.month, year: budget.year),
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
    installment.paid? ? I18n.t("filters.paid_state.paid") : I18n.t("filters.paid_state.pending")
  end

  def installment_status_badge(installment)
    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{installment_status_badge_class(installment)}") do
      paid_label(installment)
    end
  end

  def installment_status_badge_class(installment)
    installment.paid? ? "bg-emerald-200 text-emerald-950" : "bg-rose-200 text-rose-950"
  end

  def installment_row_class(installment)
    if installment.paid?
      "border-emerald-200 bg-emerald-50 text-emerald-950 hover:bg-emerald-100"
    else
      "border-rose-200 bg-rose-50 text-rose-950 hover:bg-rose-100"
    end
  end

  def installment_mobile_card_class(installment)
    installment.paid? ? "border-emerald-200 bg-emerald-50" : "border-rose-200 bg-rose-50"
  end

  def status_label
    return I18n.t("dashboards.budgets.status.exceeded") if budget_exceeded?
    return I18n.t("dashboards.budgets.status.exact") if budget.remaining_value.zero?

    I18n.t("dashboards.budgets.status.available")
  end

  def status_class
    return "bg-red-100 text-red-800" if budget_exceeded?
    return "bg-amber-100 text-amber-900" if budget.remaining_value.zero?

    "bg-emerald-100 text-emerald-800"
  end

  def budget_exceeded?
    if budget.value.negative?
      budget.remaining_value.positive?
    else
      budget.remaining_value.negative?
    end
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
