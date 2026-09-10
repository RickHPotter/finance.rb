# frozen_string_literal: true

class Views::UserCards::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :user_card, :return_to

  def initialize(user_card:, return_to: "/user_cards")
    @user_card = user_card
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: show_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_grid
          references_section
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
        h1(class: "text-3xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-4xl") { user_card.user_card_name }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          card_badge
          bank_badge
        end
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), record_audit_versions_path(item_type: "UserCard", item_id: user_card.id), variant: :outline)
        dashboard_action(I18n.t("dashboards.actions.view_transactions"), transactions_index_path, variant: :outline) if scoped_card_transactions.exists?
        dashboard_action(action_message(:edit), edit_user_card_path(user_card, return_to:), variant: :edit)
        destroy_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(UserCard, :count), scoped_card_transactions.count)
        dashboard_stat(model_attribute(UserCard, :spent), money(scoped_card_transactions.sum(:price)), emphasis: true)
        dashboard_stat(model_attribute(UserCard, :status),
                       user_card.active? ? model_attribute(UserCard, "statuses.active") : model_attribute(UserCard, "statuses.inactive"))
        dashboard_stat(model_attribute(UserCard, :card_id), user_card.card&.card_name || "-")
        dashboard_stat("Bank", user_card.card&.bank&.bank_name || "-")
        dashboard_stat(model_attribute(UserCard, :current_closing_date), localized_date(current_closing_date))
        dashboard_stat(model_attribute(UserCard, :current_due_date), localized_date(current_due_date))
        dashboard_stat(model_attribute(UserCard, :min_spend), money(user_card.min_spend), emphasis: true)
        dashboard_stat(model_attribute(UserCard, :credit_limit), money(user_card.credit_limit), emphasis: true)
        dashboard_stat(model_attribute(UserCard, :created_at), localized_date(user_card.created_at))
      end
    end
  end

  def references_section
    section_card(Reference.model_name.human(count: 2)) do
      if reference_records.present?
        div(
          class: "space-y-4",
          data: {
            controller: "reference-year-carousel",
            reference_year_carousel_years_value: reference_years.to_json
          }
        ) do
          div(class: "flex items-center justify-between gap-3") do
            button(
              type: :button,
              class: reference_year_button_class,
              data: {
                action: "reference-year-carousel#previous",
                reference_year_carousel_target: "previousButton"
              }
            ) { "Prev" }

            span(
              class: "rounded-full bg-sky-100 px-4 py-1.5 text-sm font-black uppercase tracking-[0.18em] text-sky-900",
              data: { reference_year_carousel_target: "yearBadge" }
            )

            button(
              type: :button,
              class: reference_year_button_class,
              data: {
                action: "reference-year-carousel#next",
                reference_year_carousel_target: "nextButton"
              }
            ) { "Next" }
          end

          div(class: "grid gap-3 lg:grid-cols-2 xl:grid-cols-3") do
            reference_records.each do |reference|
              div(
                class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900",
                data: {
                  reference_year_carousel_target: "card",
                  reference_year: reference.year
                }
              ) do
                div(class: "flex items-start justify-between gap-3") do
                  div(class: "min-w-0") do
                    p(class: "text-xs font-black uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") { reference_month_year_label(reference) }
                    p(class: "mt-1 text-sm font-semibold text-slate-950 dark:text-slate-100") do
                      "#{model_attribute(UserCard, :user_card_name)}: #{user_card.user_card_name}"
                    end
                  end

                  span(class: "shrink-0 rounded-full bg-sky-100 px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] text-sky-900") do
                    localized_date(reference.reference_date)
                  end
                end

                div(class: "mt-3 grid grid-cols-2 gap-3") do
                  compact_stat(model_attribute(Reference, :reference_closing_date), localized_date(reference.reference_closing_date))
                  compact_stat(model_attribute(Reference, :reference_date), localized_date(reference.reference_date), emphasis: true)
                end
              end
            end
          end
        end
      else
        empty_state
      end
    end
  end

  def movement_section
    section_card(I18n.t("reports.user_card_movement.title")) do
      render Views::Shared::AllocationTrend.new(
        url: user_card_movement_path(user_card),
        query_state: report_query_state,
        prefix: "user_card_#{user_card.id}_movement",
        translation_scope: "reports.user_card_movement",
        supplementary_sections: %i[payment_states details]
      )
    end
  end

  def categories_section
    section_card(model_attribute(CardTransaction, :categories), open: false) do
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
    section_card(model_attribute(CardTransaction, :entities), open: false) do
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
    return unless user_card.card_transactions.empty?

    LinkWithConfirmation(
      id: "user_card_dashboard_destroy_#{user_card.id}",
      text: action_message(:destroy),
      link_params: {
        href: user_card_path(user_card, return_to:),
        variant: :destructive,
        id: "delete_user_card_#{user_card.id}",
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
            compact_stat(model_attribute(CardTransaction, :price), money(entry[:total]), emphasis: true)
            compact_stat(model_attribute(CardTransaction, :count), entry[:count])
          end
        end
      end
    end
  end

  def status_badge
    colour = user_card.active? ? "bg-emerald-100 text-emerald-900" : "bg-slate-200 text-slate-700"
    label = user_card.active? ? model_attribute(UserCard, "statuses.active") : model_attribute(UserCard, "statuses.inactive")

    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{colour}") { label }
  end

  def card_badge
    span(class: neutral_badge_class) do
      user_card.card&.card_name || "-"
    end
  end

  def bank_badge
    span(class: neutral_badge_class) do
      user_card.card&.bank&.bank_name || "-"
    end
  end

  def neutral_badge_class
    "rounded-full border border-slate-300 bg-white px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-slate-700 " \
      "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300"
  end

  def show_shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm " \
      "dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none sm:rounded-3xl sm:p-6"
  end

  def entity_chip_class
    "flex min-h-12 items-center gap-2 rounded-lg border border-slate-400 bg-white px-2 py-1 text-sm text-black " \
      "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
  end

  def scoped_card_transactions
    @scoped_card_transactions ||= current_context.card_transactions.where(user_card:)
  end

  def transactions_index_path
    card_transactions_path(
      all_month_years: true,
      user_card_id: user_card.id,
      return_to: user_card_path(user_card)
    )
  end

  def category_transactions_index_path(category)
    card_transactions_path(
      all_month_years: true,
      user_card_id: user_card.id,
      card_transaction: { category_id: [ category.id ] },
      return_to: user_card_path(user_card)
    )
  end

  def entity_transactions_index_path(entity)
    card_transactions_path(
      all_month_years: true,
      user_card_id: user_card.id,
      card_transaction: { entity_id: [ entity.id ] },
      return_to: user_card_path(user_card)
    )
  end

  def reference_records
    @reference_records ||= user_card.references.where(context: current_context).order(year: :asc, month: :asc).to_a
  end

  def category_breakdowns
    @category_breakdowns ||= begin
      entries = category_records.map do |category|
        scoped_transactions = scoped_card_transactions.joins(:categories).where(categories: { id: category.id })
        { record: category, total: scoped_transactions.sum(:price), count: scoped_transactions.count }
      end

      sort_breakdowns(entries)
    end
  end

  def entity_breakdowns
    @entity_breakdowns ||= begin
      entries = entity_records.map do |entity|
        scoped_transactions = scoped_card_transactions.joins(:entities).where(entities: { id: entity.id })
        { record: entity, total: scoped_transactions.sum(:price), count: scoped_transactions.count }
      end

      sort_breakdowns(entries)
    end
  end

  def category_records
    @category_records ||= user_card.user.categories
                                   .joins(:card_transactions)
                                   .merge(scoped_card_transactions)
                                   .distinct
                                   .order(:category_name)
                                   .to_a
  end

  def entity_records
    @entity_records ||= user_card.user.entities
                                 .joins(:card_transactions)
                                 .merge(scoped_card_transactions)
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

  def current_due_date
    Date.current.change(day: user_card.due_date_day)
  end

  def current_closing_date
    current_due_date - user_card.days_until_due_date.days
  end

  def compact_stat(label, value, emphasis: false)
    div do
      p(class: "text-2xs font-bold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400") { label }
      p(class: "#{emphasis ? 'text-sm' : 'text-xs'} mt-1 font-bold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def reference_year_button_class
    "inline-flex min-h-11 min-w-20 items-center justify-center rounded-sm border border-slate-300 bg-white px-3 py-2 " \
      "text-sm font-semibold text-slate-700 shadow-sm " \
      "transition hover:border-slate-400 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40 " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700"
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

  def reference_month_year_label(reference)
    I18n.l(Date.new(reference.year, reference.month, 1), format: "%b %Y")
  end

  def reference_years
    @reference_years ||= reference_records.map(&:year).uniq.sort
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
