# frozen_string_literal: true

module ReceiptUploadAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_receipt_upload_blobs, only: %i[create update]
  end

  private

  def authorize_receipt_upload_blobs
    Array(params.dig(receipt_upload_param_key, :receipts)).compact_blank.each do |value|
      next if value.respond_to?(:tempfile)
      return head :unprocessable_entity unless value.is_a?(String)

      blob = ActiveStorage::Blob.find_signed(value)
      uploader_id = blob&.custom_metadata&.fetch("receipt_upload_user_id", nil)
      return head :unprocessable_entity unless uploader_id.to_s == current_user.id.to_s
    end
  end

  def receipt_upload_param_key
    raise NotImplementedError
  end
end
