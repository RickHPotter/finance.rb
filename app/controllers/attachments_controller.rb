# frozen_string_literal: true

class AttachmentsController < ApplicationController
  include ActiveStorage::Streaming

  def destroy
    attachment = receipt_attachment
    return head :not_found unless attachment

    parent = attachment.record
    return head :not_found unless authorized_parent?(parent)

    blob_key = attachment.blob.key

    ActiveRecord::Base.transaction do
      attachment.destroy!
      record_audit_version_for(parent, blob_key)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("attachment_row_#{attachment.id}"),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: I18n.t("attachments.deleted") })
        ]
      end
      format.html do
        redirect_back fallback_location: root_path, notice: I18n.t("attachments.deleted")
      end
    end
  end

  def download
    attachment = receipt_attachment
    return head :not_found unless attachment

    parent = attachment.record
    return head :not_found unless authorized_parent?(parent)

    expires_now
    response.headers["Cache-Control"] = "private, no-store"
    if request.headers["Range"].present?
      send_blob_byte_range_data(attachment.blob, request.headers["Range"], disposition: :attachment)
    else
      send_blob_stream(attachment.blob, disposition: :attachment)
    end
  end

  private

  def receipt_attachment
    ActiveStorage::Attachment.find_by(id: params[:id], name: "receipts", record_type: %w[CashTransaction CardTransaction])
  end

  def authorized_parent?(parent)
    parent.user_id == current_user.id && parent.context_id == current_context.id
  end

  def record_audit_version_for(parent, blob_key)
    operation = Audit::Operation.ensure_persisted!
    owner = Audit::OwnershipResolver.resolve!(parent)
    base_metadata = Audit::VersionMetadata.for(parent) || {}
    metadata = base_metadata.merge("attachments_deleted" => [ blob_key ])

    AuditVersion.create!(
      item_type: parent.class.name,
      item_id: parent.id,
      event: "update",
      owner_id: owner.owner_id,
      context_id: owner.context_id,
      mutation_source: "web",
      operation_id: operation.id,
      metadata: metadata,
      object: parent.attributes
    )
  end
end
