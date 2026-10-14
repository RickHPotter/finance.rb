# frozen_string_literal: true

class Views::Transactions::FiscalImportSection < Views::Base
  def view_template
    section(class: "rounded-lg border border-sky-300 bg-sky-50 p-3 text-slate-800 dark:border-sky-700/60 dark:bg-slate-900/50 dark:text-slate-200") do
      p(class: "mt-1 text-xs text-slate-600 dark:text-slate-400") { I18n.t("fiscal_import.hint") }

      div(class: "mt-3 grid grid-cols-1 items-center gap-2 sm:grid-cols-[minmax(0,1fr)_auto]") do
        input(
          type: :file,
          accept: ".xml,.pdf,.jpg,.jpeg,.png,.heic,application/xml,text/xml,application/pdf,image/jpeg,image/png,image/heic",
          class: "min-w-0 w-full text-xs file:mr-2 file:whitespace-nowrap file:rounded-md file:border-0 file:bg-sky-100 file:px-3 file:py-2 " \
                 "file:text-sky-900 dark:file:bg-sky-950 dark:file:text-sky-200",
          data: { fiscal_import_target: "file" }
        )
        div(class: "ml-auto flex items-center justify-end gap-2") do
          button(
            type: :button,
            class: "shrink-0 rounded-md bg-sky-700 px-3 py-2 text-xs font-semibold text-white hover:bg-sky-800 disabled:opacity-50",
            data: { action: "click->fiscal-import#importFile", fiscal_import_target: "button" }
          ) { I18n.t("fiscal_import.import_file") }
          button(
            type: :button,
            class: "shrink-0 rounded-md border border-sky-700 px-3 py-2 text-xs font-semibold text-sky-800 hover:bg-sky-100 " \
                   "disabled:opacity-50 dark:text-sky-300 dark:hover:bg-sky-950",
            data: { action: "click->fiscal-import#startCamera", fiscal_import_target: "button" }
          ) { I18n.t("fiscal_import.scan_camera") }
        end
      end

      div(class: "mt-3 hidden", data: { fiscal_import_target: "cameraPanel" }, hidden: true) do
        video(
          autoplay: true,
          muted: true,
          playsinline: true,
          class: "mx-auto max-h-72 w-full rounded-md bg-slate-950 object-contain",
          data: { fiscal_import_target: "video" }
        )
        button(
          type: :button,
          class: "mt-2 rounded-md border border-slate-400 px-3 py-2 text-xs font-semibold hover:bg-slate-100 dark:hover:bg-slate-800",
          data: { action: "click->fiscal-import#stopCamera" }
        ) { I18n.t("fiscal_import.cancel_camera") }
      end

      div(class: "mt-3 flex flex-wrap items-center gap-2") do
        label(class: "sr-only", for: "fiscal_import_state") { I18n.t("fiscal_import.state") }
        select(
          id: "fiscal_import_state",
          name: "state",
          class: "h-10 w-36 shrink-0 rounded-md border border-slate-300 bg-white px-3 text-sm text-slate-900 " \
                 "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100",
          data: {
            fiscal_import_target: "state",
            action: "change->fiscal-import#stateChanged"
          }
        ) do
          option(value: "goias", selected: true) { I18n.t("fiscal_import.states.goias") }
          option(value: "parana") { I18n.t("fiscal_import.states.parana") }
        end
        input(
          type: :text,
          inputmode: :text,
          autocomplete: :off,
          placeholder: I18n.t("fiscal_import.key_placeholder.goias"),
          class: "min-w-0 flex-1 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " \
                 "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100",
          data: {
            fiscal_import_target: "source",
            placeholder_goias: I18n.t("fiscal_import.key_placeholder.goias"),
            placeholder_parana: I18n.t("fiscal_import.key_placeholder.parana")
          }
        )
        button(
          type: :button,
          class: "rounded-md border border-sky-700 px-3 py-2 text-xs font-semibold text-sky-800 hover:bg-sky-100 " \
                 "disabled:opacity-50 dark:text-sky-300 dark:hover:bg-sky-950",
          data: { action: "click->fiscal-import#lookup", fiscal_import_target: "button" }
        ) { I18n.t("fiscal_import.lookup") }
      end

      p(class: "mt-2 text-xs", role: :status, data: { fiscal_import_target: "status" })
    end
  end
end
