# frozen_string_literal: true

class Views::Transactions::FiscalReceiptSummary < Views::Base
  def view_template
    div(class: "mt-2 rounded-md border border-sky-200 bg-sky-50 p-2 text-xs text-slate-700 dark:border-sky-800 dark:bg-slate-900 dark:text-slate-200",
        hidden: true, data: { fiscal_import_summary: true }) do
      div(class: "flex flex-wrap items-center justify-between gap-1 border-b border-sky-200 pb-1 dark:border-sky-800") do
        p(class: "font-semibold") { I18n.t("fiscal_import.source_summary.title") }
        span(class: "hidden rounded-full bg-sky-100 px-2 py-0.5 text-[10px] font-semibold text-sky-800 dark:bg-sky-950 dark:text-sky-300",
             data: { fiscal_import_target: "sourceBadge" })
      end
      dl(class: "mt-1 grid grid-cols-2 gap-x-3 gap-y-1 sm:grid-cols-3") do
        %w[products discount freight total difference].each do |key|
          div do
            dt(class: "text-slate-500 dark:text-slate-400") { I18n.t("fiscal_import.source_summary.#{key}") }
            dd(class: "font-semibold", data: { fiscal_summary_amount: key })
          end
        end
      end
      div(class: "mt-2 hidden border-t border-sky-200 pt-2 dark:border-sky-800",
          data: { fiscal_import_target: "differenceGateContainer" }) do
        label(class: "flex cursor-pointer items-start gap-2 text-xs text-amber-800 dark:text-amber-300") do
          input(
            type: :checkbox,
            id: "fiscal_difference_acknowledged",
            class: "mt-0.5 rounded border-slate-300 text-sky-600 focus:ring-sky-500",
            data: { fiscal_import_target: "differenceAck", action: "change->fiscal-import#acknowledgeDifference" }
          )
          span(data: { fiscal_import_target: "differenceGateLabel" }) do
            I18n.t("ocr.difference_gate", amount: "R$ 0,00")
          end
        end
      end
      p(class: "mt-1 text-slate-500 dark:text-slate-400") { I18n.t("fiscal_import.source_summary.hint") }
    end
  end
end
