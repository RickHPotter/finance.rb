# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OCR draft review", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  it "displays OCR badges, field confidences, and enforces the monetary difference gate" do
    draft = user.fiscal_receipt_drafts.create!(
      status: :ready,
      payload: {
        "source" => "ocr",
        "issuer" => "MERCADO OCR",
        "issued_at" => "2026-10-14T12:30:00-03:00",
        "total_cents" => 3000,
        "difference_cents" => 500,
        "items" => [
          { "description" => "ARROZ", "price_cents" => 2000, "confidence" => "high" },
          { "description" => "CAFE 5006", "price_cents" => 500, "confidence" => "low" }
        ],
        "fiscal_details" => {
          "field_confidences" => {
            "issuer" => "medium",
            "total" => "high",
            "issued_at" => "high",
            "items" => "medium"
          }
        }
      }
    )

    visit new_cash_transaction_path(fiscal_receipt_draft_id: draft.id)

    expect(page).to have_content(I18n.t("fiscal_import.messages.source_badge"))
    expect(page).to have_content(I18n.t("fiscal_import.messages.field_issuer"))
    expect(page).to have_content(I18n.t("fiscal_import.messages.field_total"))
    expect(page).to have_css("[data-ocr-confidence='low'].border-amber-500")
    expect(page).to have_css("[data-ocr-confidence='high']")

    submit_button = find("button[type='submit']:not([data-reactive-form-target='updateButton'])", match: :first)
    expect(submit_button).to be_disabled

    check "fiscal_difference_acknowledged"
    expect(submit_button).not_to be_disabled
  end

  it "displays side-by-side conflicts when structured and OCR sources disagree" do
    draft = user.fiscal_receipt_drafts.create!(
      status: :ready,
      payload: {
        "source" => "sefaz_pr",
        "access_key" => "41140978393592000146651000000000031222222235",
        "issuer" => "MERCADO PR S/A",
        "issued_at" => "2026-10-14T12:30:00-03:00",
        "total_cents" => 2500,
        "difference_cents" => 0,
        "items" => [
          { "description" => "ARROZ", "price_cents" => 2500 }
        ],
        "fiscal_details" => {
          "review_required" => true,
          "source_comparison" => [
            { "field" => "total_cents", "structured" => 2500, "ocr" => 3000, "status" => "conflict" }
          ]
        }
      }
    )

    visit new_cash_transaction_path(fiscal_receipt_draft_id: draft.id)

    expect(page).to have_content(I18n.t("ocr.comparison.conflicts_title"))
    expect(page).to have_content("25,00")
    expect(page).to have_content("30,00")
  end
end
