# frozen_string_literal: true

class Views::HealthCheck::Checks::Pagination < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :entry, :page, :query

  def initialize(entry:, page:, query:)
    @entry = entry
    @page = page
    @query = query.to_h.symbolize_keys.except(:page)
  end

  def view_template
    nav(
      class: "mt-3 flex flex-col items-center justify-between gap-2 border-t border-slate-200 pt-3 sm:flex-row dark:border-slate-700",
      aria: { label: I18n.t("health_check.details.pagination.label") }
    ) do
      p(class: "text-sm text-slate-600 dark:text-slate-400") do
        I18n.t("health_check.details.pagination.summary", page: page.number, pages: page.total_pages, count: page.total_count)
      end

      div(class: "flex items-center gap-2") do
        pagination_link(I18n.t("navigation.previous"), page.previous_page)
        pagination_link(I18n.t("navigation.next"), page.next_page)
      end
    end
  end

  private

  def pagination_link(label, target_page)
    classes = "inline-flex min-h-10 items-center justify-center rounded-md border px-4 py-2 text-sm font-semibold"
    if target_page.nil?
      span(class: "#{classes} cursor-not-allowed border-slate-200 text-slate-400 dark:border-slate-800 dark:text-slate-600") { label }
    else
      link_to(
        label,
        healthcheck_check_path(entry.key, **query.merge(page: target_page).compact_blank),
        class: "#{classes} border-slate-300 text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800",
        data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
      )
    end
  end
end
