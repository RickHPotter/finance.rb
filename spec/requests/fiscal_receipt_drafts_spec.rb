# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Fiscal receipt drafts", type: :request do
  let(:user) { create(:user, :random) }
  let(:draft) do
    {
      access_key: "52261000000000000000650010000000000000000000",
      issuer: "Mercado Exemplo",
      issued_at: "2026-10-14T12:30:00-03:00",
      total_cents: 1150,
      difference_cents: 0,
      source: "sefaz_go",
      items: [ { description: "Arroz", price_cents: 1150 } ]
    }
  end

  before { sign_in user }

  describe "POST /fiscal_receipt_drafts" do
    it "persists the extracted draft with a private source manifest" do
      expect do
        post fiscal_receipt_drafts_path, params: { draft: }, as: :json
      end.to change(user.fiscal_receipt_drafts, :count).by(1)

      expect(response).to have_http_status(:created)
      receipt_draft = user.fiscal_receipt_drafts.sole
      expect(receipt_draft.fiscal_draft).to include("issuer" => "Mercado Exemplo", "total_cents" => 1150)
      expect(receipt_draft.source).to be_attached
      expect(receipt_draft.source.blob.content_type).to eq("application/json")
      expect(JSON.parse(receipt_draft.source.download)).to include("format" => "finance-fiscal-receipt-draft-v1")
      expect(CashTransaction.count).to eq(0)
      expect(CardTransaction.count).to eq(0)
    end

    it "ignores unrecognized fields in client-submitted drafts" do
      post fiscal_receipt_drafts_path, params: { draft: draft.merge(user_id: create(:user, :random).id) }, as: :json

      expect(response).to have_http_status(:created)
      expect(user.fiscal_receipt_drafts.sole.payload).not_to have_key("user_id")
    end

    it "keeps owner-scoped Goiás page evidence with the saved receipt" do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("<html>Goiás detailed page</html>"),
        filename: "goias-nfce-detailed.html",
        content_type: "text/html",
        metadata: { custom: { receipt_upload_user_id: user.id.to_s } }
      )

      post fiscal_receipt_drafts_path, params: { draft:, evidence_signed_ids: [ blob.signed_id ] }, as: :json

      expect(response).to have_http_status(:created)
      expect(user.fiscal_receipt_drafts.sole.evidence_files.blobs).to contain_exactly(blob)
    end

    it "rejects page evidence uploaded by another user" do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("<html>Private page</html>"),
        filename: "goias-nfce-detailed.html",
        content_type: "text/html",
        metadata: { custom: { receipt_upload_user_id: create(:user, :random).id.to_s } }
      )

      post fiscal_receipt_drafts_path, params: { draft:, evidence_signed_ids: [ blob.signed_id ] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(FiscalReceiptDraft.where(user:)).not_to exist
    end
  end

  describe "GET /fiscal_receipt_drafts" do
    it "lists only the current user's drafts" do
      own_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)
      other_payload = draft.stringify_keys.merge("issuer" => "Private Receipt")
      other_draft = create(:user, :random).fiscal_receipt_drafts.create!(payload: other_payload)

      get fiscal_receipt_drafts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own_draft.payload.fetch("issuer"))
      expect(response.body).not_to include(other_draft.payload.fetch("issuer"))
    end
  end

  describe "GET /fiscal_receipt_drafts/:id/cash_transaction" do
    it "opens an owned draft in the cash transaction form and rejects other owners" do
      receipt_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)
      other_draft = create(:user, :random).fiscal_receipt_drafts.create!(payload: draft.stringify_keys)

      get cash_transaction_fiscal_receipt_draft_path(receipt_draft)

      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response.body).to include("data-fiscal-import-pending-draft-value")

      get cash_transaction_fiscal_receipt_draft_path(other_draft)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /fiscal_receipt_drafts/:id/card_transaction" do
    it "redirects to card setup when the user has no active card" do
      receipt_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)

      get card_transaction_fiscal_receipt_draft_path(receipt_draft)

      expect(response).to redirect_to(new_user_card_path)
      expect(flash[:alert]).to eq(I18n.t("fiscal_import.messages.card_required"))
    end
  end

  describe "POST /cash_transactions with a saved receipt draft" do
    let(:user_bank_account) { create(:user_bank_account, :random, user:) }

    it "attaches the original source and consumes the draft only after transaction save" do
      receipt_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)
      receipt_draft.source.attach(
        io: StringIO.new(File.read(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))),
        filename: "fiscal_receipt.xml",
        content_type: "application/xml"
      )
      receipt_draft.evidence_files.attach(
        io: StringIO.new("<html>Goiás DANFE</html>"), filename: "goias-nfce-danfe.html", content_type: "text/html"
      )
      params = Params::CashTransactions.new(
        cash_transaction: {
          description: "Imported purchase",
          date: Date.new(2026, 10, 14),
          price: -1150,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id
        },
        cash_installments: { count: 1 }
      ).params

      expect do
        post cash_transactions_path, params: params.merge(fiscal_receipt_draft_id: receipt_draft.id)
      end.to change(CashTransaction, :count).by(1)

      transaction = user.cash_transactions.order(:id).last
      expect(transaction.receipts.blobs.map { |blob| blob.filename.to_s }).to contain_exactly("fiscal_receipt.xml", "goias-nfce-danfe.html")
      expect(user.fiscal_receipt_drafts.reload).to be_empty
    end

    it "keeps the saved draft when transaction validation fails" do
      receipt_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)

      post cash_transactions_path,
           params: {
             fiscal_receipt_draft_id: receipt_draft.id,
             cash_transaction: {
               description: "",
               price: -1150,
               date: Date.new(2026, 10, 14),
               user_id: user.id,
               cash_installments_attributes: [ { number: 1, date: Date.new(2026, 10, 14), price: -1150 } ]
             }
           }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.fiscal_receipt_drafts).to exist
    end
  end

  describe "POST /card_transactions with a saved receipt draft" do
    let(:user_card) { create(:user_card, :random, user:) }

    it "attaches the original source and consumes the draft only after transaction save" do
      receipt_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)
      receipt_draft.source.attach(
        io: StringIO.new({ "source" => "sefaz_pr", "draft" => draft }.to_json),
        filename: "fiscal-source.json",
        content_type: "application/json"
      )
      receipt_draft.evidence_files.attach(
        io: StringIO.new({ format: "goias-nfce-detailed-page-v1" }.to_json),
        filename: "goias-nfce-detailed.json",
        content_type: "application/json"
      )
      params = Params::CardTransactions.new(
        card_transaction: {
          description: "Imported purchase",
          date: Date.new(2026, 10, 14),
          month: 10,
          year: 2026,
          price: -1150,
          user_id: user.id,
          user_card_id: user_card.id
        },
        card_installments: { count: 1 }
      ).params

      expect do
        post card_transactions_path, params: params.merge(fiscal_receipt_draft_id: receipt_draft.id)
      end.to change(CardTransaction, :count).by(1)

      transaction = user.card_transactions.order(:id).last
      expect(transaction.receipts.blobs.map { |blob| blob.filename.to_s }).to contain_exactly("fiscal-source.json", "goias-nfce-detailed.json")
      expect(user.fiscal_receipt_drafts.reload).to be_empty
    end

    it "returns to the chosen card rather than the card preselected when opening the draft" do
      receipt_draft = user.fiscal_receipt_drafts.create!(payload: draft.stringify_keys)
      selected_card = create(:user_card, :random, user:)
      params = Params::CardTransactions.new(
        card_transaction: {
          description: "Imported purchase on selected card",
          date: Date.new(2026, 10, 14),
          month: 10,
          year: 2026,
          price: -1150,
          user_id: user.id,
          user_card_id: selected_card.id
        },
        card_installments: { count: 1 }
      ).params

      post card_transactions_path, params: params.merge(
        fiscal_receipt_draft_id: receipt_draft.id,
        return_to: card_transactions_path(user_card_id: user_card.id)
      )

      expect(response).to redirect_to(card_transactions_path(user_card_id: selected_card.id))
      expect(user.card_transactions.find_by!(description: "Imported purchase on selected card").user_card).to eq(selected_card)
      expect(user.fiscal_receipt_drafts.reload).to be_empty
    end
  end
end
