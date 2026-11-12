# frozen_string_literal: true

class Views::Transactions::FiscalReceiptSummary < Views::Base
  def view_template
    div(class: "mt-2 rounded-md border border-sky-200 bg-sky-50 p-2 text-xs text-slate-700 dark:border-sky-800 dark:bg-slate-900 dark:text-slate-200",
        hidden: true, data: { fiscal_import_summary: true }) do
      p(class: "font-semibold") { I18n.t("fiscal_import.source_summary.title") }
      dl(class: "mt-1 grid grid-cols-2 gap-x-3 gap-y-1 sm:grid-cols-3") do
        %w[products discount freight total difference].each do |key|
          div do
            dt(class: "text-slate-500 dark:text-slate-400") { I18n.t("fiscal_import.source_summary.#{key}") }
            dd(class: "font-semibold", data: { fiscal_summary_amount: key })
          end
        end
      end
      p(class: "mt-1 text-slate-500 dark:text-slate-400") { I18n.t("fiscal_import.source_summary.hint") }
    end
  end
end
