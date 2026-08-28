# frozen_string_literal: true

class Views::Investments::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :investment, :generated_cash_transaction, :piggy_bank_return_cash_transaction, :return_to

  def initialize(investment:, generated_cash_transaction:, piggy_bank_return_cash_transaction: nil, return_to: "/investments")
    @investment = investment
    @generated_cash_transaction = generated_cash_transaction
    @piggy_bank_return_cash_transaction = piggy_bank_return_cash_transaction
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: dashboard_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_section
          investment.piggy_bank_valuation? ? valuation_section : projection_section
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 dark:border-slate-700 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-4xl") { investment.description }

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          kind_badge
          reference_badge
        end
      end

      div(class: "grid grid-cols-2 gap-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), audit_path, variant: :outline)
        dashboard_action(I18n.t("dashboards.actions.view_in_list"), investment_index_path, variant: :outline)
        dashboard_action(relationship_collection_label, relationship_collection_path, variant: :outline) if relationship_collection_path.present?
        dashboard_action(related_transaction_label, related_transaction_path, variant: :outline) if related_transaction_path.present?
        dashboard_action(action_message(:edit), edit_investment_path(investment, return_to:), variant: :edit)
        dashboard_action(action_message(:duplicate), duplicate_investment_path(investment, return_to:), variant: :duplicate)
        destroy_action if investment.can_be_destroyed?
      end
    end
  end

  def summary_section
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-5") do
        dashboard_stat(entry_amount_label, money(investment.price), emphasis: true)
        dashboard_stat(model_attribute(Investment, :investment_type_id), investment.investment_type.display_name)
        account_stat
        dashboard_stat(model_attribute(Investment, :date), localized_date(investment.date))
        dashboard_stat(I18n.t("dashboards.investments.reference_month"), I18n.l(reference_date, format: "%B %Y"))
      end
    end
  end

  def projection_section
    section_card(I18n.t("dashboards.investments.projection.title")) do
      if generated_cash_transaction.present?
        projection_summary
        projection_allocations
      else
        empty_state(I18n.t("dashboards.investments.projection.unavailable"))
      end
    end
  end

  def valuation_section
    section_card(I18n.t("dashboards.investments.valuation.title")) do
      if piggy_bank_return_cash_transaction.present?
        valuation_summary
      else
        empty_state(I18n.t("dashboards.investments.valuation.unavailable"))
      end
    end
  end

  def valuation_summary
    div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
      linked_stat(
        I18n.t("dashboards.investments.valuation.target"),
        piggy_bank_return_cash_transaction.description,
        piggy_bank_return_path
      )
      dashboard_stat(I18n.t("dashboards.investments.valuation.principal"), money(piggy_bank_principal), emphasis: true)
      dashboard_stat(I18n.t("dashboards.investments.valuation.adjustments"), money(piggy_bank_valuation_delta), emphasis: true)
      dashboard_stat(I18n.t("dashboards.investments.valuation.projected_total"), money(piggy_bank_projected_total), emphasis: true)
      dashboard_stat(I18n.t("dashboards.investments.valuation.recorded_total"), money(piggy_bank_return_cash_transaction.price))
      dashboard_stat(I18n.t("dashboards.investments.valuation.paid_total"), money(piggy_bank_paid_total))
      dashboard_stat(I18n.t("dashboards.investments.valuation.siblings"), piggy_bank_return_cash_transaction.piggy_bank_investments.size)
      dashboard_stat(I18n.t("dashboards.investments.valuation.status"), piggy_bank_status_label)
    end
  end

  def projection_summary
    div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
      linked_stat(model_attribute(CashTransaction, :description), generated_cash_transaction.description, projection_path)
      dashboard_stat(model_attribute(CashTransaction, :price), money(generated_cash_transaction.price), emphasis: true)
      dashboard_stat(model_attribute(CashTransaction, :date), localized_date(generated_cash_transaction.date))
      dashboard_stat(I18n.t("dashboards.investments.projection.entries"), generated_cash_transaction.investments.count)
    end
  end

  def projection_allocations
    div(class: "mt-4 grid gap-3 border-t border-slate-200 pt-4 dark:border-slate-700 xl:grid-cols-2") do
      allocation_group(model_attribute(CashTransaction, :categories), generated_cash_transaction.categories, &:name)
      allocation_group(model_attribute(CashTransaction, :entities), generated_cash_transaction.entities, &:entity_name)
    end
  end

  def account_stat
    div(class: stat_card_class) do
      p(class: stat_label_class) { model_attribute(Investment, :user_bank_account_id) }
      link_to investment.user_bank_account.user_bank_account_name,
              user_bank_account_path(investment.user_bank_account, return_to: investment_path(investment)),
              class: "mt-2 block text-base font-bold text-sky-700 no-underline hover:underline dark:text-sky-300 sm:text-lg",
              data: { turbo_frame: "_top", turbo_prefetch: false }
    end
  end

  def section_card(title, &)
    section(class: section_card_class, data: { controller: "show-section-card", show_section_card_open_value: true }) do
      button(
        type: :button,
        class: "flex w-full items-center justify-between gap-3 text-left",
        data: { action: "show-section-card#toggle", show_section_card_target: "button" }
      ) do
        h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") { title }
        span(class: "text-lg font-semibold leading-none text-slate-500 dark:text-slate-400", data: { show_section_card_target: "icon" }) { "−" }
      end

      div(class: "mt-4", data: { show_section_card_target: "content" }, &)
    end
  end

  def dashboard_stat(label, value, emphasis: false)
    div(class: stat_card_class) do
      p(class: stat_label_class) { label }
      p(class: "#{emphasis ? 'text-xl sm:text-2xl' : 'text-base sm:text-lg'} mt-2 font-bold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def linked_stat(label, value, href)
    div(class: stat_card_class) do
      p(class: stat_label_class) { label }
      link_to value,
              href,
              class: "mt-2 block text-base font-bold text-sky-700 no-underline hover:underline dark:text-sky-300 sm:text-lg",
              data: { turbo_frame: "_top", turbo_prefetch: false }
    end
  end

  def allocation_group(label, records)
    div(class: stat_card_class) do
      p(class: stat_label_class) { label }

      if records.empty?
        p(class: "mt-2 text-sm text-slate-500 dark:text-slate-400") { I18n.t("dashboards.empty") }
      else
        div(class: "mt-3 flex flex-wrap gap-2") do
          records.each do |record|
            span(class: allocation_badge_class) { yield(record) }
          end
        end
      end
    end
  end

  def empty_state(message)
    div(class: empty_state_class) do
      message
    end
  end

  def kind_badge
    key = investment.piggy_bank_valuation? ? "valuation" : "ordinary"
    span(class: kind_badge_class) do
      I18n.t("dashboards.investments.kind.#{key}")
    end
  end

  def entry_amount_label
    return I18n.t("dashboards.investments.valuation.adjustment") if investment.piggy_bank_valuation?

    model_attribute(Investment, :price)
  end

  def reference_badge
    span(class: reference_badge_class) do
      I18n.l(reference_date, format: "%B %Y")
    end
  end

  def dashboard_action(label, href, variant:)
    Button(
      link: href,
      variant: dashboard_action_variant(variant),
      class: dashboard_action_class(variant),
      data: { turbo_frame: "_top", turbo_prefetch: false }
    ) { label }
  end

  def destroy_action
    LinkWithConfirmation(
      id: investment.id,
      text: action_message(:destroy),
      link_params: {
        href: investment_path(investment, return_to:),
        variant: :destructive,
        id: "delete_investment_#{investment.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
      }
    )
  end

  def audit_path
    record_audit_versions_path(item_type: "Investment", item_id: investment.id)
  end

  def investment_index_path
    investments_path(
      default_year: investment.year,
      active_month_years: [ reference_month ].to_json,
      investment: { id: [ investment.id ] },
      return_to: investment_path(investment)
    )
  end

  def aggregation_path
    investments_path(
      default_year: aggregation_months.max.to_s.first(4).to_i,
      active_month_years: aggregation_months.to_json,
      investment: {
        user_bank_account_id: [ investment.user_bank_account_id ],
        investment_type_id: [ investment.investment_type_id ]
      },
      return_to: investment_path(investment)
    )
  end

  def valuation_siblings_path
    investments_path(
      default_year: valuation_months.max.to_s.first(4).to_i,
      active_month_years: valuation_months.to_json,
      investment: { piggy_bank_return_cash_transaction_id: [ piggy_bank_return_cash_transaction.id ] },
      return_to: investment_path(investment)
    )
  end

  def projection_path
    cash_transaction_path(generated_cash_transaction, return_to: investment_path(investment))
  end

  def piggy_bank_return_path
    cash_transaction_path(piggy_bank_return_cash_transaction, return_to: investment_path(investment))
  end

  def relationship_collection_label
    key = investment.piggy_bank_valuation? ? "view_valuations" : "view_aggregation"
    I18n.t("dashboards.investments.actions.#{key}")
  end

  def relationship_collection_path
    return if investment.piggy_bank_valuation? && piggy_bank_return_cash_transaction.blank?

    investment.piggy_bank_valuation? ? valuation_siblings_path : aggregation_path
  end

  def related_transaction_label
    key = investment.piggy_bank_valuation? ? "view_piggy_bank_return" : "view_projection"
    I18n.t("dashboards.investments.actions.#{key}")
  end

  def related_transaction_path
    return piggy_bank_return_path if investment.piggy_bank_valuation? && piggy_bank_return_cash_transaction.present?

    projection_path if generated_cash_transaction.present?
  end

  def aggregation_months
    @aggregation_months ||= investment.context.investments
                                      .where(user_bank_account_id: investment.user_bank_account_id, investment_type_id: investment.investment_type_id)
                                      .distinct
                                      .order(:year, :month)
                                      .pluck(:year, :month)
                                      .map { |year, month| (year * 100) + month }
  end

  def valuation_months
    @valuation_months ||= investment.context.investments
                                    .where(piggy_bank_return_cash_transaction_id: piggy_bank_return_cash_transaction.id)
                                    .distinct
                                    .order(:year, :month)
                                    .pluck(:year, :month)
                                    .map { |year, month| (year * 100) + month }
  end

  def piggy_bank_principal = piggy_bank_return_cash_transaction.piggy_bank_return_links.sum(&:return_price)

  def piggy_bank_valuation_delta = piggy_bank_return_cash_transaction.piggy_bank_investments.sum(&:price)

  def piggy_bank_projected_total = piggy_bank_principal + piggy_bank_valuation_delta

  def piggy_bank_paid_total = piggy_bank_return_cash_transaction.cash_installments.select(&:paid?).sum(&:price)

  def piggy_bank_status_label
    key = piggy_bank_return_cash_transaction.piggy_bank_group_open? ? "open" : "settled"
    I18n.t("dashboards.investments.valuation.statuses.#{key}")
  end

  def reference_month = (investment.year * 100) + investment.month

  def reference_date = Date.new(investment.year, investment.month, 1)

  def money(value) = from_cent_based_to_float(value, "R$")

  def localized_date(value) = I18n.l(value, format: :short)

  def dashboard_shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm dark:border-slate-700 " \
      "dark:bg-slate-950 dark:shadow-black/30 sm:rounded-3xl sm:p-6"
  end

  def section_card_class
    "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-900/70 sm:rounded-3xl sm:p-4"
  end

  def stat_card_class = "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-950"

  def stat_label_class = "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400"

  def allocation_badge_class
    "rounded-full border border-slate-300 bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
  end

  def empty_state_class
    "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-6 text-center text-sm text-slate-500 dark:border-slate-600 " \
      "dark:bg-slate-900 dark:text-slate-400"
  end

  def kind_badge_class
    base = "rounded-full border px-3 py-1 text-xs font-black uppercase tracking-[0.16em]"
    return "#{base} border-amber-300 bg-amber-100 text-amber-900 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-200" if investment.piggy_bank_valuation?

    "#{base} border-emerald-300 bg-emerald-100 text-emerald-900 dark:border-emerald-700 dark:bg-emerald-950 dark:text-emerald-200"
  end

  def reference_badge_class
    "rounded-full border border-slate-300 bg-slate-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-slate-700 " \
      "dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
  end

  def dashboard_action_class(variant)
    default = "border-slate-300 text-slate-700 hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
    return default if %i[primary outline].include?(variant)

    case variant
    when :edit then "border-sky-500 bg-sky-100 text-sky-900 hover:border-sky-400 hover:bg-sky-500 hover:text-white dark:bg-sky-950 dark:text-sky-200"
    when :duplicate
      "border-orange-500 bg-orange-100 text-orange-900 hover:border-orange-400 hover:bg-orange-500 hover:text-white dark:bg-orange-950 dark:text-orange-200"
    when :destroy then "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white dark:bg-red-950 dark:text-red-200"
    else default
    end
  end

  def dashboard_action_variant(variant)
    return :purple if variant == :edit

    :outline
  end
end
