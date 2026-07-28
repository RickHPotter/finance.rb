# frozen_string_literal: true

class Views::AuditVersions::Index < Views::Base
  HEADER_LINK_CLASS = "inline-flex min-h-8 items-center justify-center rounded-md border border-stone-300 px-3 py-1.5 text-xs font-semibold " \
                      "text-stone-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"

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
      main(class: "#{compact_crud_shell_class} overflow-hidden") do
        header_section
        div(class: "px-3 md:px-4") do
          render Views::Audit::FilterForm.new(url: filter_url, filters:, current_user:, record_filter:)
          render Views::Audit::VersionList.new(versions: page.records, current_user:)
          render Views::Audit::Pagination.new(page:, filters:, url: filter_url)
        end
      end
    end
  end

  private

  def header_section
    header(class: "#{compact_crud_header_class} gap-3") do
      h1(class: compact_crud_title_class) { page_title }
      link_to(
        I18n.t("audit.actions.operations"),
        audit_operations_path,
        class: HEADER_LINK_CLASS,
        data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
      )
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
