# frozen_string_literal: true

module FiscalReceiptIdentity
  extend ActiveSupport::Concern

  private

  def save_with_fiscal_identity(record)
    token = fiscal_receipt_identity_token
    return yield if token.blank?

    key = FiscalReceipts::IdentityToken.read(token, user: current_user)
    if key.blank?
      record.errors.add(:base, I18n.t("fiscal_import.messages.invalid_identity"))
      return false
    end

    current_user.with_lock do
      duplicate = FiscalDocumentLink.exists?(user: current_user, context: current_context, access_key: key)
      if duplicate && !ActiveModel::Type::Boolean.new.cast(params[:fiscal_duplicate_confirmed])
        record.errors.add(:base, I18n.t("fiscal_import.messages.duplicate_transaction"))
        return false
      end

      saved = yield
      FiscalDocumentLink.create!(user: current_user, context: current_context, transactable: record, access_key: key) if saved
      saved
    end
  end

  def fiscal_receipt_identity_token
    return params[:fiscal_identity_token] if params[:fiscal_receipt_draft_id].blank?

    current_user.fiscal_receipt_drafts.find(params[:fiscal_receipt_draft_id]).payload["identity_token"]
  end
end
