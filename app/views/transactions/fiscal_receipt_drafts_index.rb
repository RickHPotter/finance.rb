# frozen_string_literal: true

class Views::Transactions::FiscalReceiptDraftsIndex < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::Routes

  attr_reader :drafts

  def initialize(drafts:)
    @drafts = drafts
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "w-full rounded-lg bg-white p-4 shadow-sm dark:border dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none") do
        div(class: "mb-4 flex flex-col gap-3 border-b border-stone-200 pb-3 dark:border-slate-700 sm:flex-row sm:items-center sm:justify-between") do
          div(class: "min-w-0") do
            div(class: "flex flex-wrap items-center gap-x-2 gap-y-1") do
              h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700 dark:text-slate-300") do
                I18n.t("fiscal_import.inbox")
              end
              span(class: "text-xs text-stone-500 dark:text-slate-400") do
                I18n.t("fiscal_import.saved_count", count: drafts.size)
              end
            end
            p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("fiscal_import.inbox_description") }
          end
          link_to I18n.t("fiscal_import.back_to_transactions"), cash_transactions_path,
                  class: "inline-flex shrink-0 items-center justify-center rounded-md bg-sky-700 px-3 py-2 text-sm font-semibold " \
                         "text-white transition hover:bg-sky-800",
                  data: { turbo_frame: "_top" }
        end

        if drafts.empty?
          div(class: "rounded-lg border border-dashed border-slate-300 px-4 py-8 text-center dark:border-slate-700") do
            h2(class: "text-base font-semibold text-slate-900 dark:text-slate-100") { I18n.t("fiscal_import.empty_title") }
            p(class: "mx-auto mt-1 max-w-lg text-sm text-slate-600 dark:text-slate-300") do
              I18n.t("fiscal_import.empty_inbox")
            end
          end
        else
          div(class: "grid gap-3 lg:grid-cols-2") do
            drafts.each { |draft| render_draft(draft) }
          end
        end
      end
    end
  end

  private

  def render_draft(draft)
    data = draft.fiscal_draft
    div(
      class: "flex min-w-0 flex-col rounded-lg border border-slate-200 bg-white p-3 shadow-sm transition hover:shadow-md " \
             "dark:border-slate-700 dark:bg-slate-900"
    ) do
      div(class: "flex min-w-0 items-start justify-between gap-3") do
        div(class: "min-w-0") do
          p(class: "truncate text-base font-semibold text-slate-950 dark:text-slate-100") do
            data["issuer"].presence || I18n.t("fiscal_import.title")
          end
          p(class: "mt-1 text-sm text-slate-500 dark:text-slate-400") do
            [ data["issued_at"], I18n.t("fiscal_import.item_count", count: Array(data["items"]).size) ].compact_blank.join(" · ")
          end
        end
        span(class: "shrink-0 rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300") do
          draft_total(data)
        end
      end

      div(class: "mt-4 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_1fr_auto]") do
        link_to I18n.t("fiscal_import.open_cash"), cash_transaction_fiscal_receipt_draft_path(draft),
                class: primary_button_class, data: { turbo_frame: "_top" }
        link_to I18n.t("fiscal_import.open_card"), card_transaction_fiscal_receipt_draft_path(draft),
                class: secondary_button_class, data: { turbo_frame: "_top" }
        button_to(
          I18n.t("fiscal_import.delete_draft"), fiscal_receipt_draft_path(draft),
          method: :delete,
          class: "w-full rounded-lg px-3 py-2.5 text-sm font-medium text-red-700 transition hover:bg-red-50 dark:text-red-300 dark:hover:bg-red-950"
        )
      end
    end
  end

  def secondary_button_class
    "inline-flex items-center justify-center rounded-lg border border-slate-300 px-3 py-2.5 text-sm font-semibold text-slate-800 " \
      "transition hover:bg-slate-50 dark:border-slate-600 dark:text-slate-100 dark:hover:bg-slate-800"
  end

  def primary_button_class
    "inline-flex items-center justify-center rounded-lg bg-sky-700 px-3 py-2.5 text-sm font-semibold text-white shadow-sm " \
      "transition hover:bg-sky-800"
  end

  def draft_total(data)
    ActiveSupport::NumberHelper.number_to_currency(data.fetch("total_cents", 0).to_i / 100.0, unit: "R$ ", separator: ",", delimiter: ".")
  end
end
