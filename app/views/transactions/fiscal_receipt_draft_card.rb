# frozen_string_literal: true

class Views::Transactions::FiscalReceiptDraftCard < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::Routes

  attr_reader :draft, :user_card

  def initialize(draft:, user_card: nil)
    @draft = draft
    @user_card = user_card
  end

  def view_template
    div(
      id: "fiscal_receipt_draft_#{draft.id}",
      class: "flex min-w-0 flex-col rounded-lg border border-slate-200 bg-white p-3 shadow-sm transition hover:shadow-md " \
             "dark:border-slate-700 dark:bg-slate-900"
    ) do
      if draft.processing?
        render_processing_state
      elsif draft.failed?
        render_failed_state
      else
        render_ready_state
      end
    end
  end

  private

  def render_processing_state
    div(class: "flex min-w-0 items-start justify-between gap-3") do
      div(class: "min-w-0") do
        p(class: "truncate text-base font-semibold text-slate-950 dark:text-slate-100") do
          draft_title
        end
        div(class: "mt-1 flex items-center gap-1.5 text-sm text-amber-600 dark:text-amber-400") do
          span(class: "inline-block h-2.5 w-2.5 animate-pulse rounded-full bg-amber-500")
          span { I18n.t("ocr.status.processing") }
        end
      end
      span(class: "shrink-0 rounded-full bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-800 dark:bg-amber-950 dark:text-amber-300") do
        I18n.t("ocr.status.processing")
      end
    end

    div(class: "mt-4 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_1fr_auto]") do
      button(disabled: true, class: "#{primary_button_class} cursor-not-allowed opacity-50") { I18n.t("fiscal_import.open_cash") }
      button(disabled: true, class: "#{secondary_button_class} cursor-not-allowed opacity-50") { I18n.t("fiscal_import.open_card") }
      render_delete_button
    end
  end

  def render_failed_state
    div(class: "flex min-w-0 items-start justify-between gap-3") do
      div(class: "min-w-0") do
        p(class: "truncate text-base font-semibold text-slate-950 dark:text-slate-100") do
          draft_title
        end
        p(class: "mt-1 text-sm text-rose-600 dark:text-rose-400") do
          draft.ocr_error.presence || I18n.t("ocr.status.failed")
        end
      end
      span(class: "shrink-0 rounded-full bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-800 dark:bg-rose-950 dark:text-rose-300") do
        I18n.t("ocr.status.failed")
      end
    end

    div(class: "mt-4 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_auto]") do
      button_to(
        I18n.t("ocr.status.retry"), retry_ocr_fiscal_receipt_draft_path(draft, user_card_id: user_card&.id),
        method: :post,
        class: "#{primary_button_class} w-full"
      )
      render_delete_button
    end
  end

  def render_ready_state
    data = draft.fiscal_draft
    div(class: "flex min-w-0 items-start justify-between gap-3") do
      div(class: "min-w-0") do
        div(class: "flex flex-wrap items-center gap-1.5") do
          p(class: "truncate text-base font-semibold text-slate-950 dark:text-slate-100") do
            data["issuer"].presence || I18n.t("fiscal_import.title")
          end
          if data["source"] == "ocr"
            span(class: "shrink-0 rounded-full bg-sky-50 px-2 py-0.5 text-[10px] font-semibold text-sky-700 dark:bg-sky-950 dark:text-sky-300") do
              I18n.t("ocr.source_badge")
            end
          end
        end
        p(class: "mt-1 text-sm text-slate-500 dark:text-slate-400") do
          [ data["issued_at"], I18n.t("fiscal_import.item_count", count: Array(data["items"]).size) ].compact_blank.join(" · ")
        end
        if data.dig("fiscal_details", "review_required")
          p(class: "mt-1 text-xs font-medium text-amber-600 dark:text-amber-400") do
            "⚠ #{I18n.t('ocr.status.review_required')}"
          end
        end
      end
      span(class: "shrink-0 rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300") do
        draft_total(data)
      end
    end

    div(class: "mt-4 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_1fr_auto]") do
      link_to I18n.t("fiscal_import.open_cash"), cash_transaction_fiscal_receipt_draft_path(draft),
              class: primary_button_class, data: { turbo_frame: "_top" }
      link_to I18n.t("fiscal_import.open_card"), card_transaction_fiscal_receipt_draft_path(draft, user_card_id: user_card&.id),
              class: secondary_button_class, data: { turbo_frame: "_top" }
      render_delete_button
    end
  end

  def render_delete_button
    button_to(
      I18n.t("fiscal_import.delete_draft"), fiscal_receipt_draft_path(draft, user_card_id: user_card&.id),
      method: :delete,
      class: "w-full rounded-lg px-3 py-2.5 text-sm font-medium text-red-700 transition hover:bg-red-50 dark:text-red-300 dark:hover:bg-red-950"
    )
  end

  def draft_title
    if draft.source.attached?
      draft.source.filename.to_s
    else
      I18n.t("fiscal_import.title")
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
