# frozen_string_literal: true

class Views::Audit::Pagination < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :page, :filters, :url

  def initialize(page:, filters:, url:)
    @page = page
    @filters = filters.to_h.symbolize_keys.except(:page)
    @url = url
  end

  def view_template
    nav(class: "mt-5 flex flex-col items-center justify-between gap-3 border-t border-slate-200 pt-4 sm:flex-row dark:border-slate-700",
        aria: { label: I18n.t("audit.pagination.label") }) do
      p(class: "text-sm text-slate-600 dark:text-slate-400") do
        I18n.t("audit.pagination.summary", page: page.number, pages: page.total_pages, count: page.total_count)
      end

      div(class: "flex items-center gap-2") do
        pagination_link(I18n.t("navigation.previous"), page.previous_page, disabled: page.previous_page.nil?)
        pagination_link(I18n.t("navigation.next"), page.next_page, disabled: page.next_page.nil?)
      end
    end
  end

  private

  def pagination_link(label, target_page, disabled:)
    classes = "inline-flex min-h-10 items-center justify-center rounded-md border px-4 py-2 text-sm font-semibold"
    if disabled
      span(class: "#{classes} cursor-not-allowed border-slate-200 text-slate-400 dark:border-slate-800 dark:text-slate-600") { label }
    else
      query = filters.merge(page: target_page).compact_blank.to_query
      link_to(label, "#{url}?#{query}",
              class: "#{classes} border-slate-300 text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800")
    end
  end
end
