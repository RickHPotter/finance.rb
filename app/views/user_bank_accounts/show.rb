# frozen_string_literal: true

class Views::UserBankAccounts::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :user_bank_account, :return_to

  def initialize(user_bank_account:, return_to: "/user_bank_accounts")
    @user_bank_account = user_bank_account
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: show_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_grid
          movement_section
          categories_section
          entities_section
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 dark:border-slate-700 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-4xl") { user_bank_account.user_bank_account_name }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          bank_badge
        end
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), record_audit_versions_path(item_type: "UserBankAccount", item_id: user_bank_account.id), variant: :outline)
        dashboard_action(I18n.t("dashboards.actions.view_transactions"), transactions_index_path, variant: :outline) if account_cash_transactions.exists?
        dashboard_action(action_message(:edit), edit_user_bank_account_path(user_bank_account, return_to:), variant: :edit)
        destroy_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(UserBankAccount, :balance), money(user_bank_account.balance), emphasis: true)
        dashboard_stat(model_attribute(UserBankAccount, :count), account_cash_transactions.count)
        dashboard_stat(model_attribute(UserBankAccount, :spent), money(account_cash_transactions.sum(:price)), emphasis: true)
        dashboard_stat(model_attribute(UserBankAccount, :status),
                       user_bank_account.active? ? model_attribute(UserBankAccount, "statuses.active") : model_attribute(UserBankAccount, "statuses.inactive"))
        dashboard_stat(model_attribute(UserBankAccount, :bank_id), user_bank_account.bank&.bank_name || "-")
        dashboard_stat(model_attribute(UserBankAccount, :agency_number), user_bank_account.agency_number || "-")
        dashboard_stat(model_attribute(UserBankAccount, :account_number), user_bank_account.account_number || "-")
        dashboard_stat(model_attribute(UserBankAccount, :created_at), localized_date(user_bank_account.created_at))
      end
    end
  end

  def movement_section
    section_card(I18n.t("reports.bank_account_movement.title")) do
      render Views::Shared::AllocationTrend.new(
        url: user_bank_account_movement_path(user_bank_account),
        query_state: report_query_state,
        prefix: "user_bank_account_#{user_bank_account.id}_movement",
        translation_scope: "reports.bank_account_movement",
        supplementary_sections: %i[payment_states interactive_breakdowns balance_context]
      )
    end
  end

  def categories_section
    section_card(model_attribute(CashTransaction, :categories), open: false) do
      if category_breakdowns.present?
        allocation_breakdown_grid(category_breakdowns) do |entry|
          link_to category_transactions_index_path(entry[:record]), data: { turbo_frame: "_top", turbo_prefetch: false } do
            CategoryBadge(
              category: entry[:record],
              class: "min-h-12 wrap-break-word px-2 py-1 text-center text-sm",
              title: entry[:record].name
            )
          end
        end
      else
        empty_state
      end
    end
  end

  def entities_section
    section_card(model_attribute(CashTransaction, :entities), open: false) do
      if entity_breakdowns.present?
        allocation_breakdown_grid(entity_breakdowns) do |entry|
          link_to entity_transactions_index_path(entry[:record]), data: { turbo_frame: "_top", turbo_prefetch: false } do
            div(class: entity_chip_class,
                title: entry[:record].name) do
              image_tag(asset_path("avatars/#{entry[:record].avatar_name}"), class: "h-6 w-6 rounded-full") if entry[:record].avatar_name.present?
              span(class: "wrap-break-word") { entry[:record].name }
            end
          end
        end
      else
        empty_state
      end
    end
  end

  def section_card(title, open: true, &)
    section(class: "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-950/70 sm:rounded-3xl sm:p-4",
            data: { controller: "show-section-card", show_section_card_open_value: open.to_s }) do
      button(type: :button, class: "flex w-full items-center justify-between gap-3 text-left",
             data: { action: "show-section-card#toggle", show_section_card_target: "button" }) do
        h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") { title }
        span(class: "text-lg font-semibold leading-none text-slate-500 dark:text-slate-400", data: { show_section_card_target: "icon" }) { "−" }
      end

      div(class: "mt-4", data: { show_section_card_target: "content" }, &)
    end
  end

  def dashboard_stat(label, value, emphasis: false)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") { label }
      p(class: "#{emphasis ? 'text-xl sm:text-2xl' : 'text-base sm:text-lg'} mt-2 font-bold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def dashboard_action(label, href, variant:)
    Button(link: href, variant: dashboard_action_variant(variant), class: dashboard_action_class(variant), data: { turbo_frame: "_top", turbo_prefetch: false }) do
      label
    end
  end

  def destroy_action
    return unless user_bank_account.cash_transactions.empty?

    LinkWithConfirmation(
      id: "user_bank_account_dashboard_destroy_#{user_bank_account.id}",
      text: action_message(:destroy),
      link_params: {
        href: user_bank_account_path(user_bank_account, return_to:),
        variant: :destructive,
        id: "delete_user_bank_account_#{user_bank_account.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top", turbo_action: "replace" }
      }
    )
  end

  def dashboard_action_class(variant)
    default = "border-slate-300 text-slate-700 hover:bg-slate-100 dark:!border-slate-700 dark:!bg-slate-900 dark:!text-slate-300 dark:hover:!bg-slate-800"
    return default if %i[primary outline].include?(variant)

    case variant
    when :edit then "border-sky-500 bg-sky-100 text-sky-900 hover:border-sky-400 hover:bg-sky-500 hover:text-white"
    when :destroy then "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white"
    else default
    end
  end

  def dashboard_action_variant(variant)
    return :purple if variant == :edit

    :outline
  end

  def allocation_breakdown_grid(entries, &)
    div(class: "grid gap-3 lg:grid-cols-3") do
      entries.each do |entry|
        div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
          div(class: "flex items-start justify-between gap-3") do
            div(class: "min-w-0 flex-1") { yield entry }

            span(class: "shrink-0 rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{breakdown_badge_class(entry[:total])}") do
              breakdown_badge_label(entry[:total])
            end
          end

          div(class: "mt-3 grid grid-cols-2 gap-3") do
            compact_stat(model_attribute(CashTransaction, :price), money(entry[:total]), emphasis: true)
            compact_stat(model_attribute(CashTransaction, :count), entry[:count])
          end
        end
      end
    end
  end

  def status_badge
    colour = user_bank_account.active? ? "bg-emerald-100 text-emerald-900" : "bg-slate-200 text-slate-700"
    label = user_bank_account.active? ? model_attribute(UserBankAccount, "statuses.active") : model_attribute(UserBankAccount, "statuses.inactive")

    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{colour}") { label }
  end

  def bank_badge
    span(class: neutral_badge_class) do
      user_bank_account.bank&.bank_name || "-"
    end
  end

  def show_shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm " \
      "dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none sm:rounded-3xl sm:p-6"
  end

  def entity_chip_class
    "flex min-h-12 items-center gap-2 rounded-lg border border-slate-400 bg-white px-2 py-1 text-sm text-black " \
      "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
  end

  def neutral_badge_class
    "rounded-full border border-slate-300 bg-white px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-slate-700 " \
      "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300"
  end

  def account_cash_transactions
    @account_cash_transactions ||= current_context.cash_transactions.where(user_bank_account: user_bank_account)
  end

  def transactions_index_path
    cash_transactions_path(
      all_month_years: true,
      cash_transaction: { user_bank_account_id: [ user_bank_account.id ] },
      return_to: user_bank_account_path(user_bank_account)
    )
  end

  def category_transactions_index_path(category)
    cash_transactions_path(
      all_month_years: true,
      cash_transaction: { category_id: [ category.id ], user_bank_account_id: [ user_bank_account.id ] },
      return_to: user_bank_account_path(user_bank_account)
    )
  end

  def entity_transactions_index_path(entity)
    cash_transactions_path(
      all_month_years: true,
      cash_transaction: { entity_id: [ entity.id ], user_bank_account_id: [ user_bank_account.id ] },
      return_to: user_bank_account_path(user_bank_account)
    )
  end

  def category_breakdowns
    @category_breakdowns ||= begin
      entries = category_records.map do |category|
        scoped_transactions = account_cash_transactions.joins(:categories).where(categories: { id: category.id })
        { record: category, total: scoped_transactions.sum(:price), count: scoped_transactions.count }
      end

      sort_breakdowns(entries)
    end
  end

  def entity_breakdowns
    @entity_breakdowns ||= begin
      entries = entity_records.map do |entity|
        scoped_transactions = account_cash_transactions.joins(:entities).where(entities: { id: entity.id })
        { record: entity, total: scoped_transactions.sum(:price), count: scoped_transactions.count }
      end

      sort_breakdowns(entries)
    end
  end

  def category_records
    @category_records ||= user_bank_account.user.categories
                                           .joins(:cash_transactions)
                                           .merge(account_cash_transactions)
                                           .distinct
                                           .order(:category_name)
                                           .to_a
  end

  def entity_records
    @entity_records ||= user_bank_account.user.entities
                                         .joins(:cash_transactions)
                                         .merge(account_cash_transactions)
                                         .distinct
                                         .order(:entity_name)
                                         .to_a
  end

  def localized_date(value)
    I18n.l(value.to_date, format: :short)
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end

  def compact_stat(label, value, emphasis: false)
    div do
      p(class: "text-2xs font-bold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400") { label }
      p(class: "#{emphasis ? 'text-sm' : 'text-xs'} mt-1 font-bold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def breakdown_badge_class(total)
    total.negative? ? "bg-rose-200 text-rose-950" : "bg-emerald-200 text-emerald-950"
  end

  def breakdown_badge_label(total)
    total.negative? ? "Expense" : "Income"
  end

  def sort_breakdowns(entries)
    entries.sort_by { |entry| -entry[:total].abs }
  end

  def report_query_state
    @report_query_state ||= Reports::QueryState.new(params.permit(:from_date, :to_date, :granularity, :paid_state, :direction, :sort))
  rescue Reports::QueryState::InvalidState
    Reports::QueryState.new
  end

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end
end
