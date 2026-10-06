# frozen_string_literal: true

class StoredFilesController < ApplicationController
  include ActiveStorage::Streaming

  def show
    blob = ActiveStorage::Blob.find_signed(params[:signed_id])
    return head :not_found unless blob
    return head :not_found unless accessible_attachment?(blob)

    expires_now
    response.headers["Cache-Control"] = "private, no-store"

    disposition = params[:disposition].presence_in(%w[inline attachment])
    if request.headers["Range"].present?
      send_blob_byte_range_data(blob, request.headers["Range"], disposition:)
    else
      send_blob_stream(blob, disposition:)
    end
  end

  private

  def accessible_attachment?(blob)
    ActiveStorage::Attachment.where(blob_id: blob.id).includes(:record).any? do |attachment|
      case [ attachment.record_type, attachment.name ]
      when %w[CashTransaction receipts], %w[CardTransaction receipts]
        owned_receipt?(attachment.record)
      when %w[UserProfile avatar]
        true
      else
        false
      end
    end
  end

  def owned_receipt?(transaction)
    transaction.user_id == current_user.id && transaction.context_id == current_context.id
  end
end
