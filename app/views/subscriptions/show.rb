# frozen_string_literal: true

class Views::Subscriptions::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :subscription, :cash_transactions, :card_transactions, :detached_transactions, :return_to

  def initialize(subscription:, cash_transactions:, card_transactions:, detached_transactions:, return_to: "/subscriptions")
    @subscription = subscription
    @cash_transactions = cash_transactions
    @card_transactions = card_transactions
    @detached_transactions = detached_transactions
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: dashboard_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_section
          transaction_section(I18n.t("dashboards.subscriptions.open"), open_transactions, :open)
          transaction_section(I18n.t("dashboards.subscriptions.paid_history"), paid_transactions, :paid)
          render Views::Subscriptions::DetachedHistory.new(subscription:, entries: detached_transactions)
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 dark:border-slate-700 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-4xl") { subscription.description }
        p(class: "mt-2 text-sm text-slate-500 dark:text-slate-400") { subscription.comment } if subscription.comment.present?
        div(class: "mt-3") { status_badge }
      end

      div(class: "grid grid-cols-2 gap-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), audit_path, variant: :outline)
        dashboard_action(action_message(:edit), edit_subscription_path(subscription, return_to:), variant: :edit)
        render Views::Subscriptions::LifecycleActions.new(subscription:)
        destroy_action if subscription.can_be_destroyed?
      end
    end
  end

  def summary_section
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(I18n.t("dashboards.subscriptions.derived_total"), money(derived_total), emphasis: true)
        dashboard_stat(model_attribute(Subscription, :status), status_label)
        linked_count_stat(I18n.t("dashboards.subscriptions.cash_count"), cash_transactions.size, cash_index_path)
        linked_count_stat(I18n.t("dashboards.subscriptions.card_count"), card_transactions.size, card_index_path)
      end

      div(class: "mt-4 grid gap-3 border-t border-slate-200 pt-4 dark:border-slate-700 xl:grid-cols-2") do
        allocation_group(model_attribute(Subscription, :category_id), subscription.categories, :category)
        allocation_group(model_attribute(Subscription, :entity_id), subscription.entities, :entity)
      end
    end
  end

  def transaction_section(title, transactions, state)
    section_card(title, id: "subscription_#{state}_transactions") do
      if transactions.empty?
        empty_state(I18n.t("dashboards.subscriptions.empty.#{state}"))
      elsif mobile?
        div(class: "space-y-3") { transactions.each { |transaction| transaction_mobile_card(transaction) } }
      else
        transaction_table(transactions)
      end
    end
  end

  def transaction_table(transactions)
    div(class: "overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700") do
      div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
        span(class: "col-span-2") { I18n.t("dashboards.subscriptions.type") }
        span(class: "col-span-4") { model_attribute(CashTransaction, :description) }
        span(class: "col-span-2") { I18n.t("dashboards.subscriptions.source") }
        span(class: "col-span-2") { model_attribute(CashTransaction, :date) }
        span(class: "col-span-2 text-right") { model_attribute(CashTransaction, :price) }
      end

      transactions.each { |transaction| transaction_row(transaction) }
    end
  end

  def transaction_row(transaction)
    link_to transaction_path(transaction),
            class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm no-underline transition hover:bg-slate-50 " \
                   "dark:border-slate-700 dark:bg-slate-950 dark:hover:bg-slate-900",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      span(class: "col-span-2 font-bold text-slate-700 dark:text-slate-300") { transaction_type_label(transaction) }
      span(class: "col-span-4 truncate font-semibold text-slate-950 dark:text-slate-100", title: transaction.description) { transaction.description }
      span(class: "col-span-2 truncate text-slate-600 dark:text-slate-400") { transaction_source(transaction) }
      div(class: "col-span-2 flex flex-wrap items-center gap-2 text-slate-700 dark:text-slate-300") do
        span { localized_date(transaction.date) }
        due_badge(transaction) unless transaction.paid?
      end
      span(class: "col-span-2 text-right font-bold text-slate-950 dark:text-slate-100") { money(transaction.price) }
    end
  end

  def transaction_mobile_card(transaction)
    link_to transaction_path(transaction),
            class: "block rounded-xl border border-slate-200 bg-white p-3 text-left no-underline dark:border-slate-700 dark:bg-slate-950",
            data: { turbo_frame: "_top", turbo_prefetch: false } do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          p(class: "truncate font-bold text-slate-950 dark:text-slate-100") { transaction.description }
          p(class: "mt-1 text-xs text-slate-500 dark:text-slate-400") { [ transaction_type_label(transaction), transaction_source(transaction) ].join(" · ") }
        end
        p(class: "shrink-0 font-bold text-slate-950 dark:text-slate-100") { money(transaction.price) }
      end

      div(class: "mt-3 flex items-center justify-between gap-2 text-xs text-slate-600 dark:text-slate-300") do
        span { localized_date(transaction.date) }
        due_badge(transaction) unless transaction.paid?
      end
    end
  end

  def allocation_group(label, records, type)
    div(class: stat_card_class) do
      p(class: stat_label_class) { label }

      if records.empty?
        p(class: "mt-2 text-sm text-slate-500 dark:text-slate-400") { I18n.t("dashboards.empty") }
      else
        div(class: "mt-3 flex flex-wrap gap-2") do
          records.each do |record|
            link_to allocation_label(record, type),
                    allocation_path(record, type),
                    class: allocation_badge_class,
                    data: { turbo_frame: "_top", turbo_prefetch: false }
          end
        end
      end
    end
  end

  def section_card(title, id: nil, &)
    section(id:, class: section_card_class, data: { controller: "show-section-card", show_section_card_open_value: true }) do
      button(type: :button, class: "flex w-full items-center justify-between gap-3 text-left",
             data: { action: "show-section-card#toggle", show_section_card_target: "button" }) do
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

  def linked_count_stat(label, count, href)
    return dashboard_stat(label, count) if count.zero?

    div(class: stat_card_class) do
      p(class: stat_label_class) { label }
      link_to count,
              href,
              class: "mt-2 block text-lg font-bold text-sky-700 no-underline hover:underline dark:text-sky-300",
              data: { turbo_frame: "_top", turbo_prefetch: false }
    end
  end

  def empty_state(message)
    div(class: empty_state_class) do
      message
    end
  end

  def due_badge(transaction)
    key = if transaction.date.to_date < Time.zone.today
            "overdue"
          elsif transaction.date.to_date == Time.zone.today
            "today"
          else
            "future"
          end
    span(class: due_badge_class(key)) { I18n.t("dashboards.subscriptions.due.#{key}") }
  end

  def dashboard_action(label, href, variant:)
    Button(link: href, variant: dashboard_action_variant(variant), class: dashboard_action_class(variant),
           data: { turbo_frame: "_top", turbo_prefetch: false }) { label }
  end

  def destroy_action
    LinkWithConfirmation(
      id: subscription.id,
      text: action_message(:destroy),
      link_params: {
        href: subscription_path(subscription, return_to:),
        variant: :destructive,
        id: "delete_subscription_#{subscription.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
      }
    )
  end

  def status_badge
    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{status_badge_class}") { status_label }
  end

  def status_label = model_attribute(Subscription, "statuses.#{subscription.status}")

  def derived_total = cash_transactions.sum(&:price) + card_transactions.sum(&:price)

  def live_transactions = @live_transactions ||= [ *cash_transactions, *card_transactions ]

  def open_transactions = ordered_transactions(live_transactions.reject(&:paid?))

  def paid_transactions = ordered_transactions(live_transactions.select(&:paid?))

  def ordered_transactions(transactions)
    transactions.sort_by { |transaction| [ -transaction.date.to_time.to_i, transaction.class.name, transaction.id ] }
  end

  def transaction_type_label(transaction)
    key = transaction.is_a?(CashTransaction) ? "cash" : "card"
    I18n.t("dashboards.subscriptions.types.#{key}")
  end

  def transaction_source(transaction)
    return transaction.user_bank_account&.user_bank_account_name || "-" if transaction.is_a?(CashTransaction)

    transaction.user_card&.user_card_name || "-"
  end

  def transaction_path(transaction)
    return cash_transaction_path(transaction, return_to: subscription_path(subscription)) if transaction.is_a?(CashTransaction)

    card_transaction_path(transaction, return_to: subscription_path(subscription))
  end

  def allocation_label(record, type) = type == :category ? record.name : record.entity_name

  def allocation_path(record, type)
    return category_path(record, return_to: subscription_path(subscription)) if type == :category

    entity_path(record, return_to: subscription_path(subscription))
  end

  def audit_path = record_audit_versions_path(item_type: "Subscription", item_id: subscription.id)

  def cash_index_path
    cash_transactions_path(all_month_years: "1", cash_transaction: { subscription_id: [ subscription.id ] }, return_to: subscription_path(subscription))
  end

  def card_index_path
    card_transactions_path(all_month_years: "1", card_transaction: { subscription_id: [ subscription.id ] }, return_to: subscription_path(subscription))
  end

  def money(value) = from_cent_based_to_float(value, "R$")

  def localized_date(value) = I18n.l(value, format: :short)

  def dashboard_shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm dark:border-slate-700 dark:bg-slate-950 " \
      "dark:shadow-black/30 sm:rounded-3xl sm:p-6"
  end

  def section_card_class
    "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-900/70 sm:rounded-3xl sm:p-4"
  end

  def stat_card_class = "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-950"

  def stat_label_class = "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400"

  def allocation_badge_class
    "rounded-full border border-slate-300 bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-700 no-underline hover:border-sky-400 " \
      "hover:text-sky-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:text-sky-300"
  end

  def empty_state_class
    "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-6 text-center text-sm text-slate-500 dark:border-slate-600 " \
      "dark:bg-slate-950 dark:text-slate-400"
  end

  def status_badge_class
    case subscription.status
    when "active" then "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200"
    when "paused" then "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-200"
    else "bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-200"
    end
  end

  def due_badge_class(key)
    case key
    when "overdue" then "rounded-full bg-red-100 px-2 py-1 font-bold text-red-800 dark:bg-red-950 dark:text-red-200"
    when "today" then "rounded-full bg-amber-100 px-2 py-1 font-bold text-amber-800 dark:bg-amber-950 dark:text-amber-200"
    else "rounded-full bg-sky-100 px-2 py-1 font-bold text-sky-800 dark:bg-sky-950 dark:text-sky-200"
    end
  end

  def dashboard_action_class(variant)
    default = "border-slate-300 text-slate-700 hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
    return default if variant == :outline

    case variant
    when :edit then "border-sky-500 bg-sky-100 text-sky-900 hover:bg-sky-500 hover:text-white dark:bg-sky-950 dark:text-sky-200"
    when :destroy then "border-red-500 bg-red-100 text-red-900 hover:bg-red-500 hover:text-white dark:bg-red-950 dark:text-red-200"
    else default
    end
  end

  def dashboard_action_variant(variant) = variant == :edit ? :purple : :outline
end
