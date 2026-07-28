# frozen_string_literal: true

class Views::HealthCheck::Checks::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TurboStreamFrom

  FINDING_COMPONENTS = {
    "exchange_trio" => Views::HealthCheck::Checks::ExchangeTrioFinding,
    "exchange_return" => Views::HealthCheck::Checks::ExchangeReturnFinding,
    "card_exchange_projection" => Views::HealthCheck::Checks::CardExchangeProjectionFinding,
    "misplaced_exchange_intent" => Views::HealthCheck::Checks::MisplacedExchangeIntentFinding,
    "piggy_bank" => Views::HealthCheck::Checks::PiggyBankFinding
  }.freeze

  attr_reader :entry, :page, :scope, :state, :summary, :workspace_scope

  def initialize(entry:, scope:, workspace_scope:, summary:, detail:)
    @entry = entry
    @scope = scope
    @workspace_scope = workspace_scope
    @summary = summary
    @page = detail[:page]
    @state = detail[:state]
  end

  def view_template
    turbo_frame_tag "center_container" do
      main(class: "w-full px-2 py-2 sm:px-3") do
        turbo_stream_from HealthCheck::Stream.for(workspace_scope)
        header_section
        timing_and_scope
        div(class: "mt-3") { render Views::HealthCheck::Dashboard::CheckCard.new(summary:, scope: workspace_scope) }
        filters if page.present?
        detail_content
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-3 border-b border-slate-200 pb-3 sm:flex-row sm:items-start sm:justify-between dark:border-slate-700") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-sky-700 dark:text-sky-300") { I18n.t("health_check.details.eyebrow") }
        h1(class: "mt-1 wrap-break-word text-2xl font-bold text-slate-950 dark:text-slate-100") { I18n.t(entry.title_key) }
        p(class: "mt-2 max-w-3xl text-sm text-slate-600 dark:text-slate-400") { I18n.t(entry.description_key) }
      end

      div(class: "flex shrink-0 flex-wrap gap-2") do
        link_to(
          I18n.t("health_check.details.back"),
          healthcheck_path(**workspace_scope_query),
          class: secondary_button_class,
          data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
        )
        link_to(
          I18n.t("health_check.actions.rerun"),
          healthcheck_check_run_path(entry.key, **rerun_query),
          class: primary_button_class,
          data: { turbo_method: :post, turbo_frame: "center_container", turbo_prefetch: false }
        )
      end
    end
  end

  def timing_and_scope
    section(class: "mt-3 rounded-lg border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900") do
      dl(class: "grid gap-2 sm:grid-cols-2 lg:grid-cols-5") do
        metadata(I18n.t("health_check.scope.administrator"), scope.user.full_name)
        metadata(I18n.t("health_check.scope.context"), scope.context.name)
        metadata(I18n.t("health_check.scope.connections"), workspace_connection_label)
        metadata(I18n.t("health_check.details.latest_summary"), last_summary_label)
        metadata(I18n.t("health_check.details.live_evaluated"), live_evaluated_label)
      end

      if page.present? && live_newer_than_summary?
        p(class: live_notice_class) do
          I18n.t("health_check.details.live_notice")
        end
      end
    end
  end

  def filters
    form(
      action: healthcheck_check_path(entry.key),
      method: "get",
      class: "mt-3 grid gap-2 rounded-lg border border-slate-200 bg-slate-50 p-3 sm:grid-cols-2 lg:grid-cols-4 dark:border-slate-700 dark:bg-slate-900",
      data: { turbo_frame: "_top", turbo_action: "advance" }
    ) do
      hidden_scope_fields
      status_filter_field if status_filter?
      issue_filter_field if issue_codes.any?
      per_page_field
      div(class: "flex items-end") do
        button(type: "submit", class: "#{primary_button_class} w-full") { I18n.t("health_check.details.apply_filters") }
      end
    end
  end

  def hidden_scope_fields
    return if workspace_scope.all_connections?

    input(type: "hidden", name: "connected_user_id", value: workspace_scope.connected_user.id)
  end

  def rerun_query
    query = workspace_scope_query.merge(return_to: "check")
    return query if page.blank?

    query.merge(
      page: page.number,
      per_page: page.per_page,
      status_filter: page.filters["status_filter"],
      issue_filter: page.filters["issue_filter"]
    ).compact_blank
  end

  def status_filter_field
    filter_field(I18n.t("health_check.details.filters.status")) do
      select(name: "status_filter", class: select_class) do
        %w[pending paid].each do |value|
          option(value:, selected: page.filters["status_filter"] == value) { I18n.t("health_check.details.statuses.#{value}") }
        end
      end
    end
  end

  def issue_filter_field
    filter_field(I18n.t("health_check.details.filters.issue")) do
      select(name: "issue_filter", class: select_class) do
        option(value: "") { I18n.t("health_check.details.filters.all_issues") }
        issue_codes.each do |code|
          option(value: code, selected: page.filters["issue_filter"] == code) { issue_label(code) }
        end
      end
    end
  end

  def per_page_field
    filter_field(I18n.t("health_check.details.filters.per_page")) do
      select(name: "per_page", class: select_class) do
        [ 25, 50, 100 ].each do |value|
          option(value:, selected: page.per_page == value) { value }
        end
      end
    end
  end

  def filter_field(label, &)
    label(class: "block text-xs font-semibold uppercase tracking-[0.1em] text-slate-600 dark:text-slate-300") do
      span { label }
      yield
    end
  end

  def detail_content
    if state.present?
      state_panel
    elsif page.records.empty?
      empty_panel
    else
      div(id: "health_check_findings_#{entry.key}", class: "mt-3 space-y-3") do
        page.records.each { |row| render FINDING_COMPONENTS.fetch(entry.key).new(row:, entry:, workspace_scope:) }
      end
      render Views::HealthCheck::Checks::Pagination.new(entry:, page:, query: pagination_query)
    end
  end

  def state_panel
    div(
      id: "health_check_details_#{state}",
      class: "mt-3 rounded-lg border border-dashed border-slate-300 bg-white px-3 py-6 text-center dark:border-slate-700 dark:bg-slate-900"
    ) do
      h2(class: "font-bold text-slate-950 dark:text-slate-100") { I18n.t("health_check.details.states.#{state}.title") }
      p(class: "mt-2 text-sm text-slate-600 dark:text-slate-400") { I18n.t("health_check.details.states.#{state}.description") }
    end
  end

  def empty_panel
    div(
      id: "health_check_details_empty",
      class: "mt-3 rounded-lg border border-dashed border-emerald-300 bg-emerald-50 px-3 py-6 text-center dark:border-emerald-800 dark:bg-emerald-950/30"
    ) do
      h2(class: "font-bold text-emerald-900 dark:text-emerald-100") { I18n.t("health_check.details.states.empty.title") }
      p(class: "mt-2 text-sm text-emerald-800 dark:text-emerald-200") { I18n.t("health_check.details.states.empty.description") }
    end
  end

  def metadata(label, value)
    div(class: "min-w-0") do
      dt(class: "text-2xs font-semibold uppercase tracking-[0.1em] text-slate-500 dark:text-slate-400") { label }
      dd(class: "mt-1 wrap-break-word text-sm font-semibold text-slate-900 dark:text-slate-100") { value }
    end
  end

  def last_summary_label
    return I18n.t("health_check.reasons.never_run") if summary&.last_run_at.blank?

    I18n.l(summary.last_run_at, format: :shorter)
  end

  def live_evaluated_label
    return I18n.t("health_check.values.no_value") if page.blank?

    I18n.l(page.evaluated_at, format: :shorter)
  end

  def live_newer_than_summary?
    summary&.last_run_at.blank? || page.evaluated_at > summary.last_run_at
  end

  def status_filter?
    entry.key.in?(%w[exchange_return card_exchange_projection])
  end

  def issue_codes
    return [] unless entry.details.const_defined?(:ISSUE_CODES, false)

    entry.details.const_get(:ISSUE_CODES, false)
  end

  def issue_label(code)
    I18n.t(issue_translation_key(code), default: code.humanize)
  end

  def issue_translation_key(code)
    {
      "exchange_trio" => "health_check.details.issue_codes.exchange_trio.#{code}",
      "exchange_return" => "health_check.details.issue_codes.exchange_return.#{code}",
      "card_exchange_projection" => "health_check.details.issue_codes.card_exchange_projection.#{code}",
      "piggy_bank" => "health_check.details.issue_codes.piggy_bank.#{code}"
    }.fetch(entry.key, "health_check.details.issues.#{code}")
  end

  def pagination_query
    workspace_scope_query.merge(page.filters.symbolize_keys)
  end

  def workspace_scope_query
    return {} if workspace_scope.all_connections?

    { connected_user_id: workspace_scope.connected_user.id }
  end

  def workspace_connection_label
    return I18n.t("health_check.scope.all_connections") if workspace_scope.all_connections?

    workspace_scope.connected_user.full_name
  end

  def select_class
    "mt-1 min-h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-900 " \
      "dark:border-slate-600 dark:bg-slate-950 dark:text-slate-100"
  end

  def primary_button_class
    "inline-flex min-h-10 items-center justify-center rounded-md border border-sky-700 bg-sky-700 px-4 py-2 text-sm font-bold text-white " \
      "hover:bg-sky-800 dark:border-sky-500 dark:bg-sky-600 dark:hover:bg-sky-500"
  end

  def secondary_button_class
    "inline-flex min-h-10 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-bold text-slate-700 " \
      "hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
  end

  def live_notice_class
    "mt-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900 " \
      "dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-200"
  end
end
