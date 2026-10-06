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

  describe "DELETE /attachments/:id" do
    context "when authenticated as the owner of a cash transaction attachment" do
      before { sign_in user }

      it "detaches the attachment, records audit version, and responds with turbo_stream" do
        cash_transaction.receipts.attach(
          io: StringIO.new("receipt pdf data"),
          filename: "receipt.pdf",
          content_type: "application/pdf"
        )
        cash_transaction.save!
        attachment = cash_transaction.receipts.attachments.first
        blob = attachment.blob

        expect do
          delete attachment_path(attachment.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end.to change(ActiveStorage::Attachment, :count).by(-1)

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("attachment_row_#{attachment.id}")
        expect(response.body).to include(I18n.t("attachments.deleted"))

        latest_version = AuditVersion.where(item_type: "CashTransaction", item_id: cash_transaction.id).last
        expect(latest_version).to be_present
        expect(latest_version.metadata["attachments_deleted"]).to eq([ blob.key ])
        expect(blob.reload).to be_persisted
      end
    end

    context "when authenticated as the owner of a card transaction attachment" do
      before { sign_in user }

      it "detaches the attachment and responds with turbo_stream" do
        card_transaction.receipts.attach(
          io: StringIO.new("card receipt image"),
          filename: "receipt.jpg",
          content_type: "image/jpeg"
        )
        card_transaction.save!
        attachment = card_transaction.receipts.attachments.first

        expect do
          delete attachment_path(attachment.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end.to change(ActiveStorage::Attachment, :count).by(-1)

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t("attachments.deleted"))
      end
    end

    context "when authenticated as another user (non-owner)" do
      before { sign_in other_user }

      it "returns 404 not found and does not delete the attachment" do
        cash_transaction.receipts.attach(
          io: StringIO.new("secret data"),
          filename: "secret.pdf",
          content_type: "application/pdf"
        )
        cash_transaction.save!
        attachment_id = cash_transaction.receipts.attachments.first.id

        expect do
          delete attachment_path(attachment_id)
        end.not_to change(ActiveStorage::Attachment, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when attachment id does not exist" do
      before { sign_in user }

      it "returns 404 not found" do
        delete attachment_path("999999999999")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /attachments/:id/download" do
    let(:attachment) do
      cash_transaction.receipts.attach(
        io: StringIO.new("receipt pdf data"),
        filename: "receipt.pdf",
        content_type: "application/pdf"
      )
      cash_transaction.receipts.attachments.first
    end

    it "streams the owner's receipt as an attachment" do
      sign_in user

      get download_attachment_path(attachment)

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.body).to eq("receipt pdf data")
    end

    it "does not disclose another user's receipt" do
      sign_in other_user

      get download_attachment_path(attachment)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("receipt pdf data")
    end
  end

  describe "POST /rails/active_storage/direct_uploads" do
    let(:upload_params) do
      {
        blob: {
          filename: "receipt.pdf",
          byte_size: 1,
          checksum: Digest::MD5.base64digest("x"),
          content_type: "application/pdf",
          metadata: {}
        }
      }
    end

    it "requires authentication" do
      post rails_direct_uploads_path, params: upload_params, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response).not_to have_http_status(:success)
    end

    it "rejects a file larger than 10 MiB before creating a blob" do
      sign_in user

      expect do
        post rails_direct_uploads_path,
             params: upload_params.deep_merge(blob: { filename: "large.pdf", byte_size: 10.megabytes + 1 }),
             as: :json
      end.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
