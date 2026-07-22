# frozen_string_literal: true

class Views::AuditOperations::Index < Views::Base
  LINK_CLASS = "inline-flex min-h-10 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold " \
               "text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"

  include Phlex::Rails::Helpers::LinkTo

  attr_reader :page, :filters, :summaries, :current_user

  def initialize(page:, filters:, summaries:, current_user:)
    @page = page
    @filters = filters
    @summaries = summaries
    @current_user = current_user
  end

  def view_template
    turbo_frame_tag :center_container do
      main(class: "mx-auto w-full max-w-7xl px-3 py-4 sm:px-5") do
        header_section
        render Views::Audit::FilterForm.new(url: audit_operations_path, filters:, current_user:)
        operation_list
        render Views::Audit::Pagination.new(page:, filters:, url: audit_operations_path)
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-4 border-b border-slate-200 pb-5 sm:flex-row sm:items-end sm:justify-between dark:border-slate-700") do
      div do
        h1(class: "text-2xl font-black text-slate-950 sm:text-3xl dark:text-slate-100") { I18n.t("audit.operations.title") }
      end
      link_to(I18n.t("audit.actions.version_ledger"), audit_versions_path,
              class: LINK_CLASS)
    end
  end

  def operation_list
    if page.records.empty?
      p(class: "py-12 text-center text-sm text-slate-500 dark:text-slate-400") { I18n.t("audit.empty.operations") }
      return
    end

    div(class: "divide-y divide-slate-200 dark:divide-slate-700") do
      page.records.each { |operation| operation_row(operation) }
    end
  end

  def operation_row(operation)
    summary = summaries.fetch(operation.id, { count: 0, item_types: [] })

    article(class: "grid gap-4 py-5 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-center") do
      div(class: "min-w-0") do
        div(class: "flex flex-wrap items-center gap-2") do
          source_badge(operation.source)
          result_badge(operation.result)
          code(class: "wrap-break-word text-xs text-slate-500 dark:text-slate-400") { operation.id }
        end
        p(class: "mt-2 text-sm font-semibold text-slate-950 dark:text-slate-100") do
          I18n.t("audit.operations.visible_changes", count: summary[:count])
        end
        p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") do
          summary[:item_types].map { |type| type.safe_constantize&.model_name&.human || type }.join(" | ")
        end
        p(class: "mt-2 text-xs text-slate-500 dark:text-slate-400") { operation_context(operation) }
      end

      link_to(I18n.t("actions.show"), audit_operation_path(operation), class: LINK_CLASS)
    end
  end

  def operation_context(operation)
    values = [ I18n.l(operation.created_at, format: :short) ]
    if current_user.admin?
      values << "#{I18n.t('audit.fields.actor_id')}: #{operation.actor_id || I18n.t('audit.values.empty')}"
      values << "#{I18n.t('audit.fields.context_id')}: #{operation.context_id || I18n.t('audit.values.empty')}"
    elsif operation.actor_id == current_user.id
      values << I18n.t("audit.values.you")
    end
    values.join(" | ")
  end

  def source_badge(source)
    badge_class = "rounded-full border border-sky-300 bg-sky-50 px-2 py-1 text-xs font-bold uppercase text-sky-900 " \
                  "dark:border-sky-800 dark:bg-sky-950 dark:text-sky-200"
    span(class: badge_class) do
      I18n.t("audit.sources.#{source}", default: source.humanize)
    end
  end

  def result_badge(result)
    span(class: "rounded-full border border-slate-300 px-2 py-1 text-xs font-bold uppercase text-slate-700 dark:border-slate-700 dark:text-slate-200") do
      I18n.t("audit.results.#{result}")
    end
  end
end
