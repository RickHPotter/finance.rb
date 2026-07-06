# frozen_string_literal: true

class Views::Categories::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::AssetPath

  include ColoursHelper
  include TranslateHelper

  attr_reader :category

  def initialize(category:)
    @category = category
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: show_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          details_section
          counterpart_section
          user_bank_accounts_section
          user_cards_section
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 dark:border-slate-700 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-4xl") { category.name }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          colour_badge
        end
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(action_message(:edit), edit_category_path(category), variant: :edit)
        dashboard_action(action_message(:index), categories_path, variant: :outline)
        destroy_action
      end
    end
  end

  def details_section
    section_card("Details") do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(Category, :category_name), category.name)
        dashboard_stat(model_attribute(Category, :status),
                       category.active? ? model_attribute(Category, "statuses.active") : model_attribute(Category, "statuses.inactive"))
        dashboard_stat("Type", category.built_in? ? "Built In" : "Custom")
        dashboard_stat(model_attribute(Category, :created_at), localized_date(category.created_at))
        dashboard_stat(pluralise_model(CashTransaction, 2), scoped_cash_transactions.count)
        dashboard_stat(model_attribute(CashTransaction, :total_amount), money(scoped_cash_transactions.sum(:price)), emphasis: true)
        dashboard_stat(pluralise_model(CardTransaction, 2), scoped_card_transactions.count)
        dashboard_stat(model_attribute(CardTransaction, :total_amount), money(scoped_card_transactions.sum(:price)), emphasis: true)
      end
    end
  end

  def counterpart_section
    pie_chart_section(
      title: Entity.model_name.human(count: 2),
      payload: counterpart_pie_payload,
      select_id: "category_entity_source_filter",
      select_label: "Sources"
    )
  end

  def user_bank_accounts_section
    pie_chart_section(
      title: "User Bank Accounts",
      payload: user_bank_accounts_pie_payload
    )
  end

  def user_cards_section
    pie_chart_section(
      title: "User Cards",
      payload: user_cards_pie_payload
    )
  end

  def pie_chart_section(title:, payload:, select_id: nil, select_label: nil)
    section_card(title) do
      if payload[:entries].present?
        div(
          class: "space-y-4",
          data: {
            controller: "pie-breakdown-chart",
            pie_breakdown_chart_data_value: payload.to_json
          }
        ) do
          if select_id.present?
            div(class: "w-full") do
              label(for: select_id, class: "mb-2 block text-center font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400") { select_label }
              render Views::Shared::MultiSelectCombobox.new(
                name: select_id,
                options: payload[:filterOptions].map { |option_data| { label: option_data[:label], value: option_data[:id] } },
                placeholder: select_label,
                term: select_label.downcase
              )
            end
          end

          div(class: "grid gap-4 xl:grid-cols-[minmax(0,22rem)_1fr] xl:items-start") do
            div(class: "rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950") do
              div(class: "h-80") do
                canvas(class: "h-full w-full", data: { pie_breakdown_chart_target: "chartCanvas" })
              end
              p(class: "hidden py-10 text-center text-sm text-slate-500", data: { pie_breakdown_chart_target: "emptyState" }) { I18n.t("dashboards.empty") }
            end

            div(class: "grid gap-2 sm:grid-cols-2", data: { pie_breakdown_chart_target: "legend" })
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
    return unless category_destroyable?

    LinkWithConfirmation(
      id: "category_dashboard_destroy_#{category.id}",
      text: action_message(:destroy),
      link_params: {
        href: category_path(category),
        variant: :destructive,
        id: "delete_category_#{category.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
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

  def status_badge
    colour = category.active? ? "bg-emerald-100 text-emerald-900" : "bg-slate-200 text-slate-700"
    label = category.active? ? model_attribute(Category, "statuses.active") : model_attribute(Category, "statuses.inactive")

    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{colour}") { label }
  end

  def colour_badge
    span(class: neutral_badge_class) do
      category.name
    end
  end

  def show_shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm " \
      "dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none sm:rounded-3xl sm:p-6"
  end

  def neutral_badge_class
    "rounded-full border border-slate-300 bg-white px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-slate-700 " \
      "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300"
  end

  def scoped_cash_transactions
    @scoped_cash_transactions ||= current_context.cash_transactions.joins(:categories).where(categories: { id: category.id }).distinct
  end

  def scoped_card_transactions
    @scoped_card_transactions ||= current_context.card_transactions.joins(:categories).where(categories: { id: category.id }).distinct
  end

  def scoped_cash_transactions_for_payload
    @scoped_cash_transactions_for_payload ||= scoped_cash_transactions.includes(:user_bank_account, entity_transactions: :entity).to_a
  end

  def scoped_card_transactions_for_payload
    @scoped_card_transactions_for_payload ||= scoped_card_transactions.includes(:user_card, entity_transactions: :entity).to_a
  end

  def counterpart_pie_payload
    @counterpart_pie_payload ||= begin
      entries = {}
      filter_options = {}

      scoped_cash_transactions_for_payload.each do |transaction|
        source = source_filter_for_bank_account(transaction.user_bank_account)
        filter_options[source[:id]] = source

        transaction.entity_transactions.filter_map(&:entity).uniq(&:id).each do |entity|
          entry = ensure_counterpart_entry!(entries, entity)
          entry[:totalsBySource][source[:id]] += absolute_price(transaction.price)
        end
      end

      scoped_card_transactions_for_payload.each do |transaction|
        source = source_filter_for_user_card(transaction.user_card)
        filter_options[source[:id]] = source

        transaction.entity_transactions.filter_map(&:entity).uniq(&:id).each do |entity|
          entry = ensure_counterpart_entry!(entries, entity)
          entry[:totalsBySource][source[:id]] += absolute_price(transaction.price)
        end
      end

      {
        kind: "counterpart",
        filterOptions: filter_options.values.sort_by { |option| option[:label] },
        entries: serialize_filterable_entries(entries.values)
      }
    end
  end

  def user_bank_accounts_pie_payload
    @user_bank_accounts_pie_payload ||= begin
      entries = {}

      scoped_cash_transactions_for_payload.each do |transaction|
        source = transaction.user_bank_account
        entry_id = source.present? ? "bank_account_#{source.id}" : "bank_account_unassigned"
        entry = entries[entry_id] ||= {
          id: entry_id,
          name: source.present? ? source.user_bank_account_name : "Unassigned",
          total: 0
        }
        entry[:total] += absolute_price(transaction.price)
      end

      { kind: "user_bank_accounts", entries: serialize_pie_entries(entries.values) }
    end
  end

  def user_cards_pie_payload
    @user_cards_pie_payload ||= begin
      entries = {}

      scoped_card_transactions_for_payload.each do |transaction|
        source = transaction.user_card
        entry_id = source.present? ? "user_card_#{source.id}" : "user_card_unassigned"
        entry = entries[entry_id] ||= {
          id: entry_id,
          name: source.present? ? source.user_card_name : "Unassigned",
          total: 0
        }
        entry[:total] += absolute_price(transaction.price)
      end

      { kind: "user_cards", entries: serialize_pie_entries(entries.values) }
    end
  end

  def ensure_counterpart_entry!(entries, entity)
    entries[entity.id] ||= {
      id: entity.id.to_s,
      name: entity.name,
      totalsBySource: Hash.new(0)
    }
  end

  def serialize_filterable_entries(entries)
    entries.sort_by { |entry| entry[:name] }.map do |entry|
      {
        id: entry[:id],
        name: entry[:name],
        totalsBySource: entry[:totalsBySource]
      }
    end
  end

  def serialize_pie_entries(entries)
    entries.sort_by { |entry| entry[:name] }.map do |entry|
      {
        id: entry[:id],
        name: entry[:name],
        total: entry[:total],
        colour: entry[:colour]
      }.compact
    end
  end

  def source_filter_for_bank_account(user_bank_account)
    return { id: "bank_account_unassigned", label: "Bank Account: Unassigned" } if user_bank_account.blank?

    { id: "bank_account_#{user_bank_account.id}", label: "Bank Account: #{user_bank_account.user_bank_account_name}" }
  end

  def source_filter_for_user_card(user_card)
    return { id: "user_card_unassigned", label: "User Card: Unassigned" } if user_card.blank?

    { id: "user_card_#{user_card.id}", label: "User Card: #{user_card.user_card_name}" }
  end

  def absolute_price(value)
    value.to_i.abs
  end

  def category_destroyable?
    !category.built_in? && category.card_transactions.empty? && category.cash_transactions.empty? && category.investments.empty?
  end

  def localized_date(value)
    I18n.l(value.to_date, format: :short)
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end
end
