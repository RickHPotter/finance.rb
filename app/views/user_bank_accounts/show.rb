# frozen_string_literal: true

class Views::UserBankAccounts::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include ColoursHelper
  include TranslateHelper

  attr_reader :user_bank_account

  def initialize(user_bank_account:)
    @user_bank_account = user_bank_account
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: show_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_grid
          interactive_category_dashboard_section
          interactive_entity_dashboard_section
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
        dashboard_action(action_message(:edit), edit_user_bank_account_path(user_bank_account), variant: :edit)
        dashboard_action(action_message(:index), user_bank_accounts_path, variant: :outline)
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

  def categories_section
    section_card(model_attribute(CashTransaction, :categories), open: false) do
      if category_breakdowns.present?
        allocation_breakdown_grid(category_breakdowns) do |entry|
          span(
            class: "flex min-h-12 items-center justify-center wrap-break-word rounded-sm border border-black px-2 py-1 text-center text-sm",
            style: "background: #{entry[:record].hex_colour}; #{auto_text_color(entry[:record].hex_colour)}",
            title: entry[:record].name
          ) { entry[:record].name }
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
          div(class: entity_chip_class,
              title: entry[:record].name) do
            image_tag(asset_path("avatars/#{entry[:record].avatar_name}"), class: "h-6 w-6 rounded-full") if entry[:record].avatar_name.present?
            span(class: "wrap-break-word") { entry[:record].name }
          end
        end
      else
        empty_state
      end
    end
  end

  def interactive_category_dashboard_section
    interactive_breakdown_dashboard_section(
      title: "Category Interactive Dashboard",
      payload: interactive_category_dashboard_payload,
      select: { id: "interactive_category_select", label: model_attribute(CashTransaction, :category_id) },
      groups_label: model_attribute(CashTransaction, :categories),
      secondary_label: model_attribute(CashTransaction, :entities)
    )
  end

  def interactive_entity_dashboard_section
    interactive_breakdown_dashboard_section(
      title: "Entity Interactive Dashboard",
      payload: interactive_entity_dashboard_payload,
      select: { id: "interactive_entity_select", label: model_attribute(CashTransaction, :entity_id) },
      groups_label: model_attribute(CashTransaction, :entities),
      secondary_label: model_attribute(CashTransaction, :categories)
    )
  end

  def interactive_breakdown_dashboard_section(title:, payload:, select:, groups_label:, secondary_label:)
    section_card(title) do
      if payload[:items].present?
        div(
          class: "space-y-4",
          data: {
            controller: "interactive-breakdown-dashboard",
            interactive_breakdown_dashboard_data_value: payload.to_json
          }
        ) do
          div(class: "w-full") do
            div(class: "w-full") do
              label(for: select[:id], class: "mb-2 block text-center font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400") do
                select[:label]
              end

              select(
                id: select[:id],
                class: "w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm " \
                       "outline-hidden transition focus:border-sky-400 focus:ring-1 focus:ring-sky-400 dark:border-slate-700 " \
                       "dark:bg-slate-800 dark:text-slate-100 dark:focus:border-sky-500/50 dark:focus:ring-sky-500/60",
                data: {
                  interactive_breakdown_dashboard_target: "primarySelect",
                  action: "change->interactive-breakdown-dashboard#changePrimary"
                }
              ) do
                payload[:items].each do |item|
                  option(value: item[:id]) { item[:name] }
                end
              end
            end
          end

          div(class: "space-y-2") do
            p(class: "text-center font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400") { groups_label }
            div(class: "space-y-2") do
              div(
                class: "flex flex-wrap gap-2",
                data: { interactive_breakdown_dashboard_target: "groupActions" }
              )
              div(
                class: "flex flex-wrap gap-2",
                data: { interactive_breakdown_dashboard_target: "groupOptions" }
              )
            end
          end

          div(class: "space-y-2 pb-2 sm:pb-3") do
            p(class: "text-center font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400") { secondary_label }
            div(class: "space-y-2") do
              div(
                class: "flex flex-wrap gap-2",
                data: { interactive_breakdown_dashboard_target: "secondaryActions" }
              )
              div(
                class: "flex flex-wrap gap-2",
                data: { interactive_breakdown_dashboard_target: "secondaryOptions" }
              )
            end
          end

          div(class: "mt-5 rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950 sm:mt-6") do
            div(class: "h-80") do
              canvas(
                class: "h-full w-full",
                data: { interactive_breakdown_dashboard_target: "chartCanvas" }
              )
            end
            p(
              class: "hidden py-10 text-center text-sm text-slate-500",
              data: { interactive_breakdown_dashboard_target: "emptyState" }
            ) { I18n.t("dashboards.empty") }
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
        href: user_bank_account_path(user_bank_account),
        variant: :destructive,
        id: "delete_user_bank_account_#{user_bank_account.id}",
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

  def interactive_category_dashboard_payload
    @interactive_category_dashboard_payload ||= begin
      categories = {}

      account_cash_transactions_for_dashboard.each do |cash_transaction|
        append_interactive_dashboard_cash_transaction!(categories, cash_transaction)
      end

      {
        primaryKind: "category",
        secondaryKind: "entity",
        rangeStart: interactive_dashboard_range_start,
        items: serialize_interactive_dashboard_entries(categories.values)
      }
    end
  end

  def interactive_entity_dashboard_payload
    @interactive_entity_dashboard_payload ||= begin
      entities = {}

      account_cash_transactions_for_dashboard.each do |cash_transaction|
        append_interactive_entity_dashboard_cash_transaction!(entities, cash_transaction)
      end

      {
        primaryKind: "entity",
        secondaryKind: "category",
        rangeStart: interactive_dashboard_range_start,
        items: serialize_interactive_dashboard_entries(entities.values)
      }
    end
  end

  def append_interactive_dashboard_cash_transaction!(categories, cash_transaction)
    selectable_categories = cash_transaction.categories.reject { |category| interactive_dashboard_base_category_excluded?(category) }
    return if selectable_categories.blank? || cash_transaction.entity_transactions.blank? || cash_transaction.cash_installments.blank?

    visible_entities = cash_transaction.entity_transactions.filter_map(&:entity).uniq(&:id)

    selectable_categories.each do |base_category|
      category_entry = ensure_interactive_dashboard_category_entry!(categories, base_category)
      aggregate_group_entry = ensure_interactive_dashboard_aggregate_group_entry!(category_entry, base_category, type: :category)
      extra_categories = cash_transaction.categories.reject do |category|
        category.id == base_category.id || interactive_dashboard_group_category_excluded?(category)
      end.sort_by(&:name)
      group_entry = ensure_interactive_dashboard_group_entry!(category_entry, extra_categories, type: :category)

      if extra_categories.blank?
        aggregate_entity_entry = ensure_interactive_dashboard_entity_secondary_entry!(aggregate_group_entry, visible_entities)
        append_interactive_dashboard_installments!(aggregate_entity_entry, cash_transaction.cash_installments)
      end

      next if group_entry.blank?

      entity_entry = ensure_interactive_dashboard_entity_secondary_entry!(group_entry, visible_entities)
      append_interactive_dashboard_installments!(entity_entry, cash_transaction.cash_installments)
    end
  end

  def append_interactive_entity_dashboard_cash_transaction!(entities, cash_transaction)
    selectable_categories = cash_transaction.categories.reject { |category| interactive_dashboard_group_category_excluded?(category) }
    visible_entities = cash_transaction.entity_transactions.filter_map(&:entity).uniq(&:id)
    return if visible_entities.blank? || selectable_categories.blank? || cash_transaction.cash_installments.blank?

    visible_entities.each do |base_entity|
      entity_entry = ensure_interactive_dashboard_entity_entry!(entities, base_entity)
      aggregate_group_entry = ensure_interactive_dashboard_aggregate_group_entry!(entity_entry, base_entity, type: :entity)
      extra_entities = visible_entities.reject { |entity| entity.id == base_entity.id }.sort_by(&:name)
      group_entry = ensure_interactive_dashboard_group_entry!(entity_entry, extra_entities, type: :entity)

      if extra_entities.blank?
        aggregate_category_entry = ensure_interactive_dashboard_category_secondary_entry!(aggregate_group_entry, selectable_categories)
        append_interactive_dashboard_installments!(aggregate_category_entry, cash_transaction.cash_installments)
      end

      next if group_entry.blank?

      category_entry = ensure_interactive_dashboard_category_secondary_entry!(group_entry, selectable_categories)
      append_interactive_dashboard_installments!(category_entry, cash_transaction.cash_installments)
    end
  end

  def ensure_interactive_dashboard_category_entry!(categories, category)
    categories[category.id] ||= {
      id: category.id.to_s,
      record: category,
      name: category.name,
      groups: {},
      type: :category
    }
  end

  def ensure_interactive_dashboard_entity_entry!(entities, entity)
    entities[entity.id] ||= {
      id: entity.id.to_s,
      record: entity,
      name: entity.name,
      groups: {},
      type: :entity
    }
  end

  def ensure_interactive_dashboard_group_entry!(primary_entry, extra_records, type:)
    return if extra_records.blank?

    group_id = extra_records.map(&:id).join("-")

    primary_entry[:groups][group_id] ||= {
      id: group_id,
      label: interactive_dashboard_group_label(extra_records),
      memberIds: [ primary_entry[:record].id, *extra_records.map(&:id) ].sort.map(&:to_s),
      rank: 1,
      secondaryItems: {},
      type:
    }
  end

  def ensure_interactive_dashboard_aggregate_group_entry!(primary_entry, base_record, type:)
    primary_entry[:groups]["__all__"] ||= {
      id: "__all__",
      label: "ONLY #{base_record.name}",
      memberIds: [ base_record.id.to_s ],
      rank: -1,
      secondaryItems: {},
      type:
    }
  end

  def interactive_dashboard_group_label(extra_categories)
    "+ #{extra_categories.map(&:name).join(' & ')}"
  end

  def ensure_interactive_dashboard_entity_secondary_entry!(group_entry, entities)
    sorted_entities = entities.sort_by(&:name)
    entity_ids = sorted_entities.map(&:id)
    entity_id = entity_ids.join("-")

    group_entry[:secondaryItems][entity_id] ||= {
      record: sorted_entities.first,
      id: entity_id,
      memberIds: entity_ids.map(&:to_s),
      name: sorted_entities.map(&:name).join(" / "),
      avatarPaths: sorted_entities.filter_map { |entity| entity.avatar_name.present? ? asset_path("avatars/#{entity.avatar_name}") : nil },
      rank: sorted_entities.length,
      total: 0,
      points: Hash.new(0)
    }
  end

  def ensure_interactive_dashboard_category_secondary_entry!(group_entry, categories)
    sorted_categories = categories.sort_by(&:name)
    category_ids = sorted_categories.map(&:id)
    category_id = category_ids.join("-")

    group_entry[:secondaryItems][category_id] ||= {
      record: sorted_categories.first,
      id: category_id,
      memberIds: category_ids.map(&:to_s),
      name: sorted_categories.map(&:name).join(" / "),
      swatchHexes: sorted_categories.filter_map(&:hex_colour).first(3),
      rank: sorted_categories.length,
      total: 0,
      points: Hash.new(0)
    }
  end

  def append_interactive_dashboard_installments!(entity_entry, cash_installments)
    cash_installments.each do |cash_installment|
      amount = cash_installment.price.to_i
      month_key = cash_installment.date.to_date.beginning_of_month.iso8601

      entity_entry[:total] += amount
      entity_entry[:points][month_key] += amount
    end
  end

  def serialize_interactive_dashboard_entries(entries)
    entries.sort_by { |entry| entry[:name] }.map do |entry|
      {
        id: entry[:id],
        name: entry[:name],
        groups: entry[:groups].values.sort_by { |group| [ group[:rank], group[:label] ] }.map do |group|
          {
            id: group[:id],
            label: group[:label],
            memberIds: group[:memberIds],
            secondaryItems: sort_breakdowns(group[:secondaryItems].values).map do |item|
              item.except(:record, :rank).merge(
                points: item[:points].sort_by { |month_year, _| month_year }.map { |month_year, value| { x: month_year, y: value } }
              )
            end
          }
        end
      }
    end
  end

  def interactive_dashboard_range_start
    earliest_date = account_cash_transactions.joins(:cash_installments, :categories)
                                             .where.not(categories: { category_name: [ "EXCHANGE", "EXCHANGE RETURN" ] })
                                             .minimum("installments.date")
    return if earliest_date.blank?

    earliest_date.to_date.beginning_of_month.iso8601
  end

  def account_cash_transactions_for_dashboard
    @account_cash_transactions_for_dashboard ||= account_cash_transactions
                                                 .includes(:cash_installments, :categories, entity_transactions: :entity)
                                                 .to_a
  end

  def interactive_dashboard_base_category_excluded?(category)
    category.built_in? && category.attributes["category_name"].in?([ "EXCHANGE", "EXCHANGE RETURN" ])
  end

  def interactive_dashboard_group_category_excluded?(category)
    category.built_in? && category.attributes["category_name"] == "EXCHANGE RETURN"
  end

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end
end
