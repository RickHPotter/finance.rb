# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceiptDraft, type: :model do
  let(:user) { create(:user, :random) }
  let(:payload) do
    {
      "issuer" => "Mercado Exemplo",
      "issued_at" => "2026-10-14T12:30:00-03:00",
      "total_cents" => 1975,
      "items" => [ { "description" => "Arroz", "price_cents" => 1150 } ]
    }
  end

  it "stores an owned fiscal draft separately from financial transactions" do
    receipt_draft = described_class.create!(user:, payload:)

    expect(user.fiscal_receipt_drafts).to contain_exactly(receipt_draft)
    expect(receipt_draft.fiscal_draft).to eq(payload)
    expect(CashTransaction.count).to eq(0)
    expect(CardTransaction.count).to eq(0)
  end

  it "accepts a private JSON source manifest for key or URL imports" do
    receipt_draft = described_class.new(user:, payload:)
    receipt_draft.source.attach(
      io: StringIO.new({ "source" => "sefaz_pr", "draft" => payload }.to_json),
      filename: "fiscal-source.json",
      content_type: "application/json"
    )

    expect(receipt_draft).to be_valid
  end

  it "accepts a free product alongside a paid product" do
    receipt_draft = described_class.new(
      user:,
      payload: payload.merge("items" => [ { "description" => "Arroz", "price_cents" => 1975 },
                                          { "description" => "Free Arroz", "price_cents" => 0 } ])
    )

    expect(receipt_draft).to be_valid
  end

  it "rejects non-object and oversized payloads" do
    invalid_payload = described_class.new(user:, payload: %w[not an object])
    oversized_payload = described_class.new(user:, payload: { "data" => "x" * 256.kilobytes })

    expect(invalid_payload).not_to be_valid
    expect(invalid_payload.errors).to include(:payload)
    expect(oversized_payload).not_to be_valid
    expect(oversized_payload.errors).to include(:payload)
  end

  it "rejects imported rows without a description or positive integer amount" do
    invalid_rows = described_class.new(
      user:,
      payload: payload.merge("items" => [ { "description" => "", "price_cents" => "1150" } ])
    )

    expect(invalid_rows).not_to be_valid
    expect(invalid_rows.errors).to include(:payload)
  end

  it "allows an empty payload when status is processing or failed" do
    processing_draft = described_class.new(user:, status: :processing, payload: {})
    failed_draft = described_class.new(user:, status: :failed, payload: {}, ocr_error: "Unreadable")

    expect(processing_draft).to be_valid
    expect(failed_draft).to be_valid
  end

  it "requires a valid payload when status is ready" do
    ready_draft_without_payload = described_class.new(user:, status: :ready, payload: {})

    expect(ready_draft_without_payload).not_to be_valid
    expect(ready_draft_without_payload.errors).to include(:payload)
  end

  it "allows partial OCR payloads with empty items or zero/missing total when status is ready" do
    partial_ocr = described_class.new(
      user:,
      status: :ready,
      payload: { "source" => "ocr", "issuer" => "LOJA DEGRADADA", "total_cents" => 0, "items" => [] }
    )

    expect(partial_ocr).to be_valid
  end

  it "still rejects empty items for non-OCR structured payloads" do
    structured_empty = described_class.new(
      user:,
      status: :ready,
      payload: payload.merge("source" => "sefaz_pr", "items" => [])
    )

    expect(structured_empty).not_to be_valid
    expect(structured_empty.errors).to include(:payload)
  end
end

# == Schema Information
#
# Table name: fiscal_receipt_drafts
# Database name: primary
#
#  id         :bigint           not null, primary key
#  ocr_error  :text
#  payload    :jsonb            not null
#  status     :string           default("ready"), not null
#  created_at :datetime         not null, indexed => [user_id]
#  updated_at :datetime         not null
#  user_id    :bigint           not null, indexed, indexed => [created_at]
#
# Indexes
#
#  index_fiscal_receipt_drafts_on_user_id                 (user_id)
#  index_fiscal_receipt_drafts_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
