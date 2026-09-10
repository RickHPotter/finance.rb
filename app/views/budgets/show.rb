# frozen_string_literal: true

class Views::Budgets::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :budget, :return_to

  def initialize(budget:, return_to: "/budgets")
    @budget = budget
    @return_to = return_to
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
          rule_badges
        end
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), record_audit_versions_path(item_type: "Budget", item_id: budget.id), variant: :outline)
        dashboard_action(I18n.t("dashboards.actions.view_in_list"), budget_index_path, variant: :outline)
        dashboard_action(action_message(:edit), edit_budget_path(budget, return_to:), variant: :edit)
        dashboard_action(action_message(:duplicate), duplicate_budget_path(budget, return_to:), variant: :duplicate)
        destroy_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2") do
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
        dashboard_stat(model_attribute(Budget, :active), boolean_label(budget.active?))
        dashboard_stat(model_attribute(Budget, :inclusive), boolean_label(budget.inclusive?))
        dashboard_stat(model_attribute(Budget, :first_installment_only), boolean_label(budget.first_installment_only?))
      end
    end
  end

  def consumption_section
    section_card(I18n.t("dashboards.budgets.consumption")) do
      render Views::Shared::BudgetPerformance.new(budget:, url: budget_performance_path(budget))
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

  def allocation_group(label, records)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500") { label }

      if records.empty?
        p(class: "mt-2 text-sm text-slate-500") { I18n.t("dashboards.empty") }
      else
        div(class: "mt-3 flex flex-wrap justify-center gap-2") do
          if label == model_attribute(Budget, :categories)
            records.each do |category|
              CategoryBadge(
                category:,
                class: "min-h-12 break-words px-2 py-1 text-center text-sm",
                title: category.name
              )
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
        href: budget_path(budget, return_to:),
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
      budget: { id: [ budget.id ] },
      return_to: budget_path(budget)
    )
  end

  def active_month_years_param(year, month)
    [ Date.new(year, month, 1).strftime("%Y%m").to_i ].to_json
  end

  def categories
    @categories ||= budget.categories.order(:category_name).to_a
  end

  def entities
    @entities ||= budget.entities.order(:entity_name).to_a
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end

  def rule_label(rule, enabled)
    I18n.t("dashboards.budgets.rules.#{rule}.#{enabled ? 'enabled' : 'disabled'}")
  end

  def boolean_label(value)
    I18n.t("dashboards.budgets.boolean.#{value ? 'yes' : 'no'}")
  end
end
