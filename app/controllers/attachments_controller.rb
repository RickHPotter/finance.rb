# frozen_string_literal: true

class AttachmentsController < ApplicationController
  def destroy
    blob = ActiveStorage::Blob.find_signed(params[:blob_signed_id])
    return head :not_found unless blob

    attachment = ActiveStorage::Attachment.find_by(blob_id: blob.id)
    return head :not_found unless attachment

    parent = attachment.record
    record_user = parent.respond_to?(:user) ? parent.user : nil
    return head :forbidden unless record_user == current_user

    blob_key = blob.key
    attachment.purge

    record_audit_version_for(parent, blob_key) if parent.respond_to?(:versions)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("attachment_row_#{params[:blob_signed_id]}"),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: I18n.t("attachments.deleted") })
        ]
      end
      format.html do
        redirect_back fallback_location: root_path, notice: I18n.t("attachments.deleted")
      end
    end
  end

  private

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
