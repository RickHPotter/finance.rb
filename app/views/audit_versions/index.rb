# frozen_string_literal: true

class Views::AuditVersions::Index < Views::Base
  LINK_CLASS = "inline-flex min-h-10 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold " \
               "text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"

  include Phlex::Rails::Helpers::LinkTo

  attr_reader :page, :filters, :current_user, :record_filter

  def initialize(page:, filters:, current_user:, record_filter: false)
    @page = page
    @filters = filters
    @current_user = current_user
    @record_filter = record_filter
  end

  def view_template
    turbo_frame_tag :center_container do
      main(class: "mx-auto w-full max-w-7xl px-2 py-2 sm:px-3") do
        header_section
        render Views::Audit::FilterForm.new(url: filter_url, filters:, current_user:, record_filter:)
        render Views::Audit::VersionList.new(versions: page.records, current_user:)
        render Views::Audit::Pagination.new(page:, filters:, url: filter_url)
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-3 border-b border-slate-200 pb-3 sm:flex-row sm:items-end sm:justify-between dark:border-slate-700") do
      div do
        h1(class: "text-2xl font-black text-slate-950 sm:text-3xl dark:text-slate-100") { page_title }
      end
      div(class: "flex flex-wrap gap-2") do
        if current_user.admin?
          link_to(
            I18n.t("tabs.health_check"),
            healthcheck_path,
            id: "audit_health_check_link",
            class: LINK_CLASS,
            data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
          )
        end
        link_to(
          I18n.t("audit.actions.operations"),
          audit_operations_path,
          class: LINK_CLASS,
          data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
        )
      end
    end
  end

  def page_title
    return I18n.t("audit.versions.title") unless record_filter

    type = filters["item_subtype"].presence || filters["item_type"]
    model_name = type.safe_constantize&.model_name&.human || type
    I18n.t("audit.versions.record_title", model: model_name, id: filters["item_id"])
  end

  def filter_url
    return audit_versions_path unless record_filter

    type = filters["item_subtype"].presence || filters["item_type"]
    record_audit_versions_path(item_type: type, item_id: filters["item_id"])
  end
end
