# frozen_string_literal: true

class Views::AuditOperations::Show < Views::Base
  LINK_CLASS = "inline-flex min-h-10 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold " \
               "text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"

  include Phlex::Rails::Helpers::LinkTo

  attr_reader :operation, :page, :filters, :current_user

  def initialize(operation:, page:, filters:, current_user:)
    @operation = operation
    @page = page
    @filters = filters
    @current_user = current_user
  end

  def view_template
    turbo_frame_tag :center_container do
      main(class: "mx-auto w-full max-w-7xl px-3 py-4 sm:px-5") do
        header_section
        operation_summary
        render Views::Audit::VersionList.new(versions: page.records, current_user:)
        render Views::Audit::Pagination.new(page:, filters:, url: audit_operation_path(operation))
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-4 border-b border-slate-200 pb-5 sm:flex-row sm:items-end sm:justify-between dark:border-slate-700") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase text-sky-700 dark:text-sky-300") { I18n.t("audit.operations.operation") }
        h1(class: "mt-1 wrap-break-word font-mono text-lg font-bold text-slate-950 sm:text-xl dark:text-slate-100") { operation.id }
      end
      div(class: "flex flex-wrap gap-2") do
        link_to(I18n.t("audit.rollback.preview"), admin_audit_operation_rollback_preview_path(operation), class: LINK_CLASS) if current_user.admin?
        link_to(I18n.t("navigation.back"), audit_operations_path, class: LINK_CLASS)
      end
    end
  end

  def operation_summary
    section(class: "grid gap-3 border-b border-slate-200 py-5 sm:grid-cols-2 xl:grid-cols-4 dark:border-slate-700") do
      summary_value(I18n.t("audit.fields.source"), I18n.t("audit.sources.#{operation.source}", default: operation.source.humanize))
      summary_value(I18n.t("audit.fields.result"), I18n.t("audit.results.#{operation.result}"))
      summary_value(I18n.t("audit.fields.created_at"), I18n.l(operation.created_at, format: :short))
      summary_value(I18n.t("audit.fields.visible_versions"), page.total_count)

      if current_user.admin?
        summary_value(I18n.t("audit.fields.actor_id"), operation.actor_id || I18n.t("audit.values.empty"))
        summary_value(I18n.t("audit.fields.context_id"), operation.context_id || I18n.t("audit.values.empty"))
        summary_value(I18n.t("audit.fields.request_id"), operation.request_id || I18n.t("audit.values.empty"))
        summary_value(I18n.t("audit.fields.parent_operation_id"), operation.parent_operation_id || I18n.t("audit.values.empty"))
        operation_metadata
      end
    end
  end

  def summary_value(label, value)
    div(class: "min-w-0") do
      p(class: "text-xs font-semibold uppercase text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 wrap-break-word text-sm font-semibold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def operation_metadata
    details(class: "sm:col-span-2 xl:col-span-4") do
      summary(class: "cursor-pointer text-sm font-semibold text-slate-600 dark:text-slate-300") { I18n.t("audit.raw.operation_metadata") }
      pre(class: "mt-3 max-h-80 overflow-auto rounded-md bg-slate-950 p-3 text-xs text-emerald-200") do
        JSON.pretty_generate(operation.metadata)
      end
    end
  end
end
