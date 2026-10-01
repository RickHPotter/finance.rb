# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Attachments", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:user_card) { create(:user_card, :random, user:) }

  let(:cash_transaction) do
    create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account:,
      price: -5000,
      description: "Coffee & Food"
    )
  end

  let(:card_transaction) do
    create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card:,
      price: -3000,
      description: "Book purchase"
    )
  end

  describe "DELETE /attachments/:blob_signed_id" do
    context "when authenticated as the owner of a cash transaction attachment" do
      before { sign_in user }

      it "purges the attachment, records audit version, and responds with turbo_stream" do
        cash_transaction.receipts.attach(
          io: StringIO.new("receipt pdf data"),
          filename: "receipt.pdf",
          content_type: "application/pdf"
        )
        cash_transaction.save!
        attachment = cash_transaction.receipts.attachments.first
        blob = attachment.blob
        signed_id = blob.signed_id

        expect do
          delete attachment_path(signed_id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end.to change(ActiveStorage::Attachment, :count).by(-1)
                                                        .and change(ActiveStorage::Blob, :count).by(-1)

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("attachment_row_#{signed_id}")
        expect(response.body).to include(I18n.t("attachments.deleted"))

        latest_version = AuditVersion.where(item_type: "CashTransaction", item_id: cash_transaction.id).last
        expect(latest_version).to be_present
        expect(latest_version.metadata["attachments_deleted"]).to eq([ blob.key ])
      end
    end

    context "when authenticated as the owner of a card transaction attachment" do
      before { sign_in user }

      it "purges the attachment and responds with turbo_stream" do
        card_transaction.receipts.attach(
          io: StringIO.new("card receipt image"),
          filename: "receipt.jpg",
          content_type: "image/jpeg"
        )
        card_transaction.save!
        attachment = card_transaction.receipts.attachments.first
        blob = attachment.blob
        signed_id = blob.signed_id

        expect do
          delete attachment_path(signed_id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end.to change(ActiveStorage::Attachment, :count).by(-1)

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t("attachments.deleted"))
      end
    end

    context "when authenticated as another user (non-owner)" do
      before { sign_in other_user }

      it "returns 403 forbidden and does not delete the attachment" do
        cash_transaction.receipts.attach(
          io: StringIO.new("secret data"),
          filename: "secret.pdf",
          content_type: "application/pdf"
        )
        cash_transaction.save!
        signed_id = cash_transaction.receipts.attachments.first.blob.signed_id

        expect do
          delete attachment_path(signed_id)
        end.not_to change(ActiveStorage::Attachment, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when signed_id does not exist" do
      before { sign_in user }

      it "returns 404 not found" do
        delete attachment_path("non_existent_signed_id")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
