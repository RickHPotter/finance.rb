# frozen_string_literal: true

class DirectUploadsController < ApplicationController
  ALLOWED_RECEIPT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
    image/heic
    application/xml
    text/xml
    application/zip
  ].freeze

  MAX_RECEIPT_SIZE = 10.megabytes

  def create
    blob_attributes = params.expect(blob: [ :filename, :byte_size, :checksum, :content_type, { metadata: {} } ]).to_h.symbolize_keys
    byte_size = Integer(blob_attributes[:byte_size], exception: false)

    unless blob_attributes[:filename].present? && blob_attributes[:checksum].present? &&
           ALLOWED_RECEIPT_TYPES.include?(blob_attributes[:content_type]) && byte_size&.positive? && byte_size <= MAX_RECEIPT_SIZE
      return head :unprocessable_entity
    end

    blob_attributes[:byte_size] = byte_size
    blob_attributes[:metadata] = {
      custom: { receipt_upload_user_id: current_user.id.to_s }
    }
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_attributes)

    render json: direct_upload_response(blob)
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing, ArgumentError, TypeError
    head :unprocessable_entity
  end

  private

  def direct_upload_response(blob)
    blob.as_json(root: false, methods: :signed_id).merge(
      direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      }
    )
  end
end
