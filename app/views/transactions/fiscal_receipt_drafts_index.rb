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
      div(class: "mx-auto max-w-4xl p-4 sm:p-6") do
        div(class: "mb-5 flex flex-wrap items-center justify-between gap-3") do
          h1(class: "text-xl font-semibold text-slate-900 dark:text-slate-100") { I18n.t("fiscal_import.inbox") }
          link_to I18n.t("fiscal_import.back_to_transactions"), cash_transactions_path,
                  class: "rounded-md bg-sky-700 px-4 py-2 text-sm font-semibold text-white",
                  data: { turbo_frame: "_top" }
        end

        if drafts.empty?
          p(class: "rounded-lg border border-slate-200 p-5 text-sm text-slate-600 dark:border-slate-700 dark:text-slate-300") do
            I18n.t("fiscal_import.empty_inbox")
          end
        else
          div(class: "space-y-3") do
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
      class: "flex flex-col gap-3 rounded-lg border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-900 " \
             "sm:flex-row sm:items-center sm:justify-between"
    ) do
      div(class: "min-w-0") do
        p(class: "truncate font-medium text-slate-900 dark:text-slate-100") { data["issuer"].presence || I18n.t("fiscal_import.title") }
        p(class: "mt-1 text-sm text-slate-600 dark:text-slate-300") do
          [ data["issued_at"], I18n.t("fiscal_import.item_count", count: Array(data["items"]).size) ].compact_blank.join(" · ")
        end
      end

      div(class: "flex flex-wrap gap-2") do
        link_to I18n.t("fiscal_import.open_cash"), cash_transaction_fiscal_receipt_draft_path(draft),
                class: secondary_button_class, data: { turbo_frame: "_top" }
        link_to I18n.t("fiscal_import.open_card"), card_transaction_fiscal_receipt_draft_path(draft),
                class: secondary_button_class, data: { turbo_frame: "_top" }
        button_to(
          I18n.t("fiscal_import.delete_draft"), fiscal_receipt_draft_path(draft),
          method: :delete,
          class: "rounded-md px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-50 dark:text-red-300 dark:hover:bg-red-950"
        )
      end
    end
  end

  def secondary_button_class
    "rounded-md border border-slate-300 px-3 py-2 text-sm font-medium text-slate-800 hover:bg-slate-50 " \
      "dark:border-slate-600 dark:text-slate-100 dark:hover:bg-slate-800"
  end
end
