# frozen_string_literal: true

class Views::Transactions::FiscalImportModal < Views::Base
  include Phlex::Rails::Helpers::Routes

  attr_reader :modal_id, :transaction_type, :transaction_url

  def initialize(modal_id:, transaction_type:, transaction_url:)
    @modal_id = modal_id
    @transaction_type = transaction_type
    @transaction_url = transaction_url
  end

  def view_template
    ModalShell(
      id: modal_id,
      title: I18n.t("fiscal_import.title"),
      options: {
        content_class: "w-[calc(100vw-1rem)] max-w-2xl max-h-[calc(100dvh-1rem)] overflow-y-auto !p-3 text-slate-900 " \
                       "dark:text-slate-100 sm:w-[calc(100vw-2rem)] sm:max-h-none sm:overflow-visible sm:!p-6",
        content_data: {
          controller: "fiscal-import",
          fiscal_import_url_value: fiscal_receipt_imports_path,
          fiscal_import_transaction_url_value: transaction_url,
          fiscal_import_transaction_type_value: transaction_type,
          fiscal_import_direct_upload_url_value: rails_direct_uploads_path,
          fiscal_import_review_message_value: I18n.t("fiscal_import.review"),
          fiscal_import_messages_value: I18n.t("fiscal_import.messages")
        }
      }
    ) do
      render Views::Transactions::FiscalImportSection.new

      button(
        type: :button,
        class: "mt-4 w-full rounded-md bg-sky-700 px-4 py-2 text-sm font-semibold text-white hover:bg-sky-800 disabled:opacity-50",
        hidden: true,
        disabled: true,
        data: { action: "click->fiscal-import#continueToTransaction", fiscal_import_target: "continueButton" }
      ) { I18n.t("fiscal_import.continue") }
    end
  end
end
