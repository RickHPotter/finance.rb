# frozen_string_literal: true

class FiscalReceiptDraftsController < ApplicationController
  include TabsConcern

  before_action -> { set_tabs(active_menu: :cash, active_sub_menu: :pix) }

  def index
    drafts = current_user.fiscal_receipt_drafts.with_attached_source.recent
    render Views::Transactions::FiscalReceiptDraftsIndex.new(drafts:, user_card: selected_user_card)
  end

  def create
    payload = fiscal_draft_payload
    key = FiscalReceipts::IdentityToken.read(payload["identity_token"], user: current_user)
    return render json: { error: I18n.t("fiscal_import.messages.invalid_identity") }, status: :unprocessable_content if key.blank? || key != payload["access_key"]

    current_user.with_lock do
      existing = existing_verified_draft(key)
      if existing && !ActiveModel::Type::Boolean.new.cast(params[:duplicate_confirmed])
        render json: { error: I18n.t("fiscal_import.messages.duplicate_draft"),
                       existing_draft_url: fiscal_receipt_drafts_path(user_card_id: selected_user_card&.id,
                                                                      anchor: "fiscal_receipt_draft_#{existing.id}") }, status: :conflict
        return
      end

      save_receipt_draft(payload)
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    render json: { error: I18n.t("fiscal_import.messages.upload_failed") }, status: :unprocessable_content
  end

  def destroy
    current_user.fiscal_receipt_drafts.find(params[:id]).destroy!
    redirect_to fiscal_receipt_drafts_path(user_card_id: selected_user_card&.id), notice: I18n.t("fiscal_import.deleted"), status: :see_other
  end

  def cash_transaction
    redirect_to new_cash_transaction_path(fiscal_receipt_draft_id: owned_draft.id), status: :see_other
  end

  def card_transaction
    unless current_user.user_cards.active.exists?
      redirect_to new_user_card_path, alert: I18n.t("fiscal_import.messages.card_required"), status: :see_other
      return
    end

    redirect_to new_card_transaction_path(fiscal_receipt_draft_id: owned_draft.id, user_card_id: selected_user_card&.id), status: :see_other
  end

  private

  def selected_user_card
    @selected_user_card ||= current_user.user_cards.active.find_by(id: params[:user_card_id]) if params[:user_card_id].present?
  end

  def save_receipt_draft(payload)
    receipt_draft = current_user.fiscal_receipt_drafts.new(payload:)
    attach_uploaded_source(receipt_draft) if params[:source_signed_id].present?
    attach_uploaded_evidence(receipt_draft)
    attach_manifest_source(receipt_draft) unless receipt_draft.source.attached?

    if receipt_draft.save
      render json: { id: receipt_draft.id }, status: :created
    else
      render json: { error: receipt_draft.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  def fiscal_draft_payload
    payload = params.require(:draft)
    payload = JSON.parse(payload) if payload.is_a?(String)
    return {} unless payload.respond_to?(:permit)

    payload.permit(:access_key, :identity_token, :issuer, :issued_at, :total_cents, :difference_cents, :source, :discount_cents, :freight_cents,
                   items: %i[description price_cents],
                   fiscal_details: [ :model, { document_totals: %i[vProd vDesc vFrete vSeg vOutro vNF],
                                               items: [ :product_code, :quantity, :unit, :unit_price,
                                                        { amounts: %i[vProd vDesc vFrete vSeg vOutro] } ] } ]).to_h
  end

  def existing_verified_draft(key)
    current_user.fiscal_receipt_drafts.where("payload ->> 'access_key' = ?", key).find do |draft|
      FiscalReceipts::IdentityToken.read(draft.payload["identity_token"], user: current_user) == key
    end
  end

  def attach_uploaded_source(receipt_draft)
    receipt_draft.source.attach(owned_upload_blob(params[:source_signed_id]))
  end

  def attach_uploaded_evidence(receipt_draft)
    signed_ids = Array(params[:evidence_signed_ids]).compact_blank
    raise ActiveRecord::RecordNotFound if signed_ids.size > 3

    signed_ids.each do |signed_id|
      blob = owned_upload_blob(signed_id)
      raise ActiveRecord::RecordNotFound unless %w[application/json text/html].include?(blob.content_type)

      receipt_draft.evidence_files.attach(blob)
    end
  end

  def owned_upload_blob(signed_id)
    blob = ActiveStorage::Blob.find_signed!(signed_id)
    uploader_id = blob.custom_metadata.fetch("receipt_upload_user_id", nil)
    raise ActiveRecord::RecordNotFound unless uploader_id.to_s == current_user.id.to_s

    blob
  end

  def attach_manifest_source(receipt_draft)
    manifest = {
      format: "finance-fiscal-receipt-draft-v1",
      saved_at: Time.current.iso8601,
      draft: receipt_draft.fiscal_draft
    }
    receipt_draft.source.attach(
      io: StringIO.new(manifest.to_json),
      filename: "fiscal-receipt-source.json",
      content_type: "application/json"
    )
  end

  def owned_draft
    @owned_draft ||= current_user.fiscal_receipt_drafts.with_attached_source.find(params[:id])
  end
end
