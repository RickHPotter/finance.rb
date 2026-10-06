# frozen_string_literal: true

module Components
  class TransactionReceiptsList < Base
    include TranslateHelper
    include CacheHelper
    include Phlex::Rails::Helpers::ButtonTo

    attr_reader :transaction

    def initialize(transaction:)
      @transaction = transaction
    end

    def view_template
      section(
        class: "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-950/70 sm:rounded-3xl sm:p-4",
        data: { controller: "show-section-card", show_section_card_open_value: true }
      ) do
        button(
          type: :button,
          class: "flex w-full items-center justify-between gap-3 text-left",
          data: { action: "show-section-card#toggle", show_section_card_target: "button" }
        ) do
          h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") do
            plain I18n.t("attachments.title")
          end
          span(class: "text-lg font-semibold leading-none text-slate-500 dark:text-slate-400", data: { show_section_card_target: "icon" }) { "−" }
        end

        div(class: "mt-4", data: { show_section_card_target: "content" }) do
          if receipt_attachments.any?
            div(class: "space-y-2") do
              receipt_attachments.each do |attachment|
                render_receipt_row(attachment)
              end
            end
          else
            div(class: "rounded-xl border border-dashed border-slate-200 p-4 text-center text-xs text-slate-400 dark:border-slate-800") do
              plain I18n.t("attachments.no_attachments")
            end
          end
        end
      end
    end

    private

    def receipt_attachments
      @receipt_attachments ||= transaction.receipts.attachments.includes(:blob).to_a
    end

    def render_receipt_row(attachment)
      receipt = attachment.blob
      div(
        id: "attachment_row_#{attachment.id}",
        class: "flex items-center justify-between rounded-xl border border-slate-200 bg-white/70 p-3 text-sm " \
               "dark:border-slate-800 dark:bg-slate-900/70 gap-3"
      ) do
        div(class: "flex items-center gap-3 min-w-0 flex-1") do
          cached_icon(:paperclip)
          div(class: "min-w-0 flex-1") do
            p(class: "font-medium text-slate-900 dark:text-slate-100 truncate text-xs sm:text-sm") { receipt.filename.to_s }
            p(class: "text-2xs text-slate-400") { ActiveSupport::NumberHelper.number_to_human_size(receipt.byte_size) }
          end
        end

        div(class: "flex items-center gap-2 shrink-0") do
          a(
            href: Rails.application.routes.url_helpers.download_attachment_path(attachment, only_path: true),
            class: "inline-flex items-center gap-1 rounded-lg border border-slate-200 bg-white px-2.5 py-1 text-xs font-semibold " \
                   "text-blue-600 hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-800 dark:text-blue-400 dark:hover:bg-slate-700",
            download: true,
            title: I18n.t("attachments.download")
          ) do
            plain I18n.t("attachments.download")
          end

          button_to(
            Rails.application.routes.url_helpers.attachment_path(attachment),
            method: :delete,
            class: "inline-flex items-center justify-center rounded-lg border border-rose-200 bg-rose-50 p-1.5 text-rose-600 " \
                   "hover:bg-rose-100 dark:border-rose-900/50 dark:bg-rose-950/50 dark:text-rose-400 dark:hover:bg-rose-900/50",
            data: { turbo_confirm: I18n.t("attachments.delete_confirm") },
            title: I18n.t("attachments.delete")
          ) do
            cached_icon(:little_x)
          end
        end
      end
    end
  end
end
