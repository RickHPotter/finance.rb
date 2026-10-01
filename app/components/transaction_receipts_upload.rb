# frozen_string_literal: true

module Components
  class TransactionReceiptsUpload < Base
    include TranslateHelper
    include CacheHelper
    include Phlex::Rails::Helpers::AssetPath
    include Phlex::Rails::Helpers::Routes
    include Phlex::Rails::Helpers::ButtonTo

    attr_reader :transaction, :form

    def initialize(transaction:, form: nil)
      @transaction = transaction
      @form = form
    end

    def view_template
      div(
        class: "mb-3 rounded-2xl border border-slate-200 bg-white/70 p-4 backdrop-blur dark:border-slate-800 dark:bg-slate-900/70",
        data: {
          controller: "attachment-upload",
          attachment_upload_model_name_value: model_param_key,
          attachment_upload_direct_upload_url_value: direct_upload_url,
          attachment_upload_existing_count_value: existing_receipts.size,
          attachment_upload_max_files_value: 5,
          attachment_upload_max_file_size_value: 10.megabytes.to_i,
          attachment_upload_too_large_message_value: I18n.t("attachments.too_large"),
          attachment_upload_invalid_type_message_value: I18n.t("attachments.invalid_type"),
          attachment_upload_max_count_message_value: I18n.t("attachments.max_count"),
          attachment_upload_uploading_message_value: I18n.t("attachments.uploading")
        }
      ) do
        header_row
        dropzone
        existing_attachments_list if existing_receipts.any?
        pending_attachments_list
        hidden_inputs_container
      end
    end

    private

    def direct_upload_url
      Rails.application.routes.url_helpers.rails_direct_uploads_path
    end

    def model_param_key
      transaction.model_name.param_key
    end

    def existing_receipts
      @existing_receipts ||= transaction.persisted? ? transaction.receipts.to_a : []
    end

    def header_row
      div(class: "mb-3 flex items-center justify-between") do
        div(class: "flex items-center gap-2") do
          cached_icon(:paperclip)
          h3(class: "text-sm font-bold uppercase tracking-wider text-slate-900 dark:text-slate-100") do
            plain I18n.t("attachments.title")
          end
        end

        span(
          class: "rounded-full bg-slate-100 px-2 py-0.5 font-mono text-xs font-semibold text-slate-600 dark:bg-slate-800 dark:text-slate-400",
          data: { attachment_upload_target: "counter" }
        ) do
          plain "#{existing_receipts.size} / 5"
        end
      end
    end

    def dropzone
      div(
        class: "group relative flex flex-col items-center justify-center rounded-xl border-2 border-dashed border-slate-300 p-4 " \
               "transition-colors hover:border-blue-500 hover:bg-blue-50/5 dark:border-slate-700 dark:hover:border-blue-400 cursor-pointer",
        data: {
          attachment_upload_target: "dropzone",
          action: "dragover->attachment-upload#dragOver dragleave->attachment-upload#dragLeave drop->attachment-upload#drop"
        }
      ) do
        input(
          type: "file",
          multiple: true,
          accept: "application/pdf,image/jpeg,image/png,image/heic,application/xml,text/xml,application/zip,.pdf,.jpg,.jpeg,.png,.heic,.xml,.zip",
          class: "absolute inset-0 opacity-0 cursor-pointer w-full h-full",
          data: {
            attachment_upload_target: "input",
            action: "change->attachment-upload#handleFiles"
          }
        )

        div(class: "flex flex-col items-center gap-1.5 text-center pointer-events-none") do
          div(
            class: "rounded-full bg-slate-100 p-2 text-slate-500 group-hover:bg-blue-100 group-hover:text-blue-600 dark:bg-slate-800 " \
                   "dark:text-slate-400 dark:group-hover:bg-blue-900/50 dark:group-hover:text-blue-400"
          ) do
            cached_icon(:paperclip)
          end
          p(class: "text-xs font-medium text-slate-700 dark:text-slate-300") do
            plain I18n.t("attachments.drop_files")
          end
          p(class: "text-2xs text-slate-500 dark:text-slate-400") do
            plain I18n.t("attachments.hint")
          end
        end
      end
    end

    def existing_attachments_list
      div(class: "mt-3 space-y-2", id: "existing_attachments") do
        existing_receipts.each do |receipt|
          div(
            id: "attachment_row_#{receipt.signed_id}",
            class: "flex items-center justify-between rounded-lg border border-slate-200 bg-white/40 p-2 text-xs text-slate-700 " \
                   "dark:border-slate-800 dark:bg-slate-800/40 dark:text-slate-300 gap-2"
          ) do
            div(class: "flex items-center gap-2 min-w-0 flex-1") do
              cached_icon(:paperclip)
              span(class: "truncate font-medium") { receipt.filename.to_s }
              span(class: "text-2xs text-slate-400 shrink-0") { ActiveSupport::NumberHelper.number_to_human_size(receipt.byte_size) }
            end

            div(class: "flex items-center gap-2 shrink-0") do
              a(
                href: Rails.application.routes.url_helpers.rails_blob_path(receipt, disposition: "attachment", only_path: true),
                class: "text-blue-600 hover:text-blue-700 dark:text-blue-400 p-1 hover:underline",
                download: true,
                title: I18n.t("attachments.download")
              ) do
                plain I18n.t("attachments.download")
              end

              button_to(
                Rails.application.routes.url_helpers.attachment_path(receipt.signed_id),
                method: :delete,
                class: "text-rose-500 hover:text-rose-700 p-1",
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

    def pending_attachments_list
      div(class: "mt-3 space-y-2", data: { attachment_upload_target: "list" })
    end

    def hidden_inputs_container
      div(data: { attachment_upload_target: "hiddenContainer" })
    end
  end
end
