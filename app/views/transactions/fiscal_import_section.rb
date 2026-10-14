# frozen_string_literal: true

class Views::Transactions::FiscalImportSection < Views::Base
  def view_template
    section(class: "mb-5 rounded-lg border border-sky-300 bg-sky-50 p-3 text-slate-800 dark:border-sky-700/60 dark:bg-slate-900/50 dark:text-slate-200") do
      h3(class: "text-sm font-semibold") { I18n.t("fiscal_import.title") }
      p(class: "mt-1 text-xs text-slate-600 dark:text-slate-400") { I18n.t("fiscal_import.xml_hint") }

      div(class: "mt-3 flex flex-wrap items-center gap-2") do
        input(
          type: :file,
          accept: ".xml,application/xml,text/xml",
          class: "max-w-full text-xs file:mr-2 file:rounded-md file:border-0 file:bg-sky-100 file:px-3 file:py-2 " \
                 "file:text-sky-900 dark:file:bg-sky-950 dark:file:text-sky-200",
          data: { fiscal_import_target: "file" }
        )
        button(
          type: :button,
          class: "rounded-md bg-sky-700 px-3 py-2 text-xs font-semibold text-white hover:bg-sky-800 disabled:opacity-50",
          data: { action: "click->fiscal-import#import", fiscal_import_target: "button" }
        ) { I18n.t("fiscal_import.import") }
      end

      p(class: "mt-2 text-xs", role: :status, data: { fiscal_import_target: "status" })
    end
  end
end
