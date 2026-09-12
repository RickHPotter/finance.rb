# frozen_string_literal: true

class Views::Ledgers::Month < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :ledger_context

  def initialize(context:)
    @ledger_context = context
  end

  def view_template
    turbo_frame_tag "month_year_container_#{ledger_context[:month_year]}" do
      section(class: "mt-5 rounded-2xl border border-slate-200 bg-white p-3 shadow-sm sm:p-4 dark:border-slate-800 dark:bg-slate-900") do
        div(class: "mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between") do
          h2(class: "text-left text-lg font-bold text-slate-950 dark:text-white") { month_label }
          span(class: "text-left text-xs text-slate-500 sm:text-right dark:text-slate-400") do
            I18n.t("ledgers.month.summary", count: ledger_context[:total_count])
          end
        end

        if ledger_context[:rows].any?
          div(class: "grid gap-3") { ledger_context[:rows].each { |row| render Views::Ledgers::Row.new(row:) } }
        else
          render Views::Ledgers::EmptyState.new
        end

        render Views::Ledgers::Total.new(count: ledger_context[:total_count], amount: ledger_context[:total_amount])
        pagination if total_pages > 1
      end
    end
  end

  private

  def month_label
    date = Date.new(ledger_context[:month_year] / 100, ledger_context[:month_year] % 100, 1)
    I18n.l(date, format: "%B %Y")
  end

  def pagination
    nav(class: "mt-3 flex items-center justify-between", aria: { label: I18n.t("ledgers.pagination.label") }) do
      pagination_link(I18n.t("ledgers.pagination.previous"), ledger_context[:page] - 1, disabled: ledger_context[:page] <= 1)
      span(class: "text-xs text-slate-500 dark:text-slate-400") do
        I18n.t("ledgers.pagination.status", page: ledger_context[:page], pages: total_pages)
      end
      pagination_link(I18n.t("ledgers.pagination.next"), ledger_context[:page] + 1, disabled: ledger_context[:page] >= total_pages)
    end
  end

  def pagination_link(label, page, disabled:)
    classes = "rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-semibold dark:border-slate-700"
    if disabled
      span(class: "#{classes} cursor-not-allowed opacity-40") { label }
    else
      link_to(label, page_path(page), class: "#{classes} hover:bg-slate-100 dark:hover:bg-slate-800",
                                      data: { turbo_frame: "month_year_container_#{ledger_context[:month_year]}" })
    end
  end

  def page_path(page)
    query = ledger_context[:canonical_params].merge(page:)
    "#{ledger_context[:month_path]}?#{Rack::Utils.build_nested_query(query)}"
  end

  def total_pages
    (ledger_context[:total_count].to_f / ledger_context[:per_page]).ceil
  end
end
