# frozen_string_literal: true

module Components
  class TransactionReceiptsUpload < Base
    include TranslateHelper
    include CacheHelper
    include ComponentsHelper
    include Phlex::Rails::Helpers::AssetPath
    include Phlex::Rails::Helpers::Routes

    attr_reader :transaction, :form

    def initialize(transaction:, form: nil)
      @transaction = transaction
      @form = form
    end

    def view_template
      div(
        class: "flex items-stretch border-y py-2 md:border-l md:pl-2 dark:border-slate-700/50",
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
        attachment_button
        attachment_modal
        hidden_inputs_container
      end
    end

    private

    def modal_id
      @modal_id ||= "#{model_param_key}_attachments_modal_#{transaction.id || 'new'}"
    end

    def direct_upload_url
      Rails.application.routes.url_helpers.rails_direct_uploads_path
    end

    def model_param_key
      transaction.model_name.param_key
    end

    def existing_receipts
      @existing_receipts ||= transaction.persisted? ? transaction.receipts.to_a : []
    end

    def attachment_button
      button(
        type: :button,
        id: "#{model_param_key}_attachments_button",
        class: "flex h-full min-h-[3.5rem] w-full md:w-auto items-center justify-center gap-2 rounded-lg border border-slate-300 " \
               "bg-white px-3 sm:px-4 py-2 font-medium text-slate-700 shadow-sm transition-colors hover:border-slate-400 hover:bg-slate-50 " \
               "dark:border-slate-700 dark:bg-slate-800/80 dark:text-slate-200 dark:hover:border-slate-600 dark:hover:bg-slate-800 cursor-pointer",
        title: I18n.t("attachments.title"),
        data: {
          modal_target: modal_id,
          modal_toggle: modal_id,
          action: "dragover->attachment-upload#dragOver dragleave->attachment-upload#dragLeave drop->attachment-upload#drop"
        }
      ) do
        span(class: "text-slate-500 dark:text-slate-400 shrink-0") { cached_icon(:paperclip) }
        span(class: "text-xs font-semibold whitespace-nowrap") { I18n.t("attachments.title") }
        span(
          class: "flex h-5 min-w-5 items-center justify-center rounded-full bg-slate-100 px-1 font-mono text-xs font-bold text-slate-700 " \
                 "border border-slate-200 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200",
          data: { attachment_upload_target: "counter" }
        ) do
          plain existing_receipts.size.to_s
        end
      end
    end

    def attachment_modal
      ModalShell(
        id: modal_id,
        title: I18n.t("attachments.title"),
        options: {
          content_class: "w-[calc(100vw-2rem)] max-w-lg text-slate-900 dark:text-slate-100"
        }
      ) do
        div(class: "space-y-4") do
          modal_header_info
          dropzone
          existing_attachments_list if existing_receipts.any?
          pending_attachments_list
          modal_footer
        end
      end
    end

    def modal_header_info
      div(class: "flex items-center justify-between text-xs text-slate-500 dark:text-slate-400") do
        span { I18n.t("attachments.hint") }
        span(
          class: "rounded-full bg-slate-100 px-2 py-0.5 font-mono font-semibold text-slate-600 dark:bg-slate-800 dark:text-slate-400",
          data: { attachment_upload_target: "counter", format: "fraction" }
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

              a(
                href: Rails.application.routes.url_helpers.attachment_path(receipt.signed_id),
                class: "text-rose-500 hover:text-rose-700 p-1 cursor-pointer",
                data: {
                  turbo_method: :delete,
                  turbo_confirm: I18n.t("attachments.delete_confirm"),
                  action: "click->attachment-upload#decrementExisting"
                },
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

    def modal_footer
      div(class: "flex justify-end pt-3 border-t border-slate-200 dark:border-slate-800") do
        Button(
          type: :button,
          variant: :primary,
          size: :sm,
          data: { modal_hide: modal_id }
        ) do
          plain I18n.t("navigation.close", default: "Close")
        end
      end
    end

    def hidden_inputs_container
      div(data: { attachment_upload_target: "hiddenContainer" })
    end
  end
end
