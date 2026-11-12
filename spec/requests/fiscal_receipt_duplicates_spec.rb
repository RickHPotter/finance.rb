# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Fiscal receipt duplicate protection", type: :request do
  let(:user) { create(:user, :random) }
  let(:key) { "41140978393592000146651000000000031222222235" }
  let(:token) { FiscalReceipts::IdentityToken.issue(user:, access_key: key) }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:card) { create(:user_card, user:, card_kind: "prepaid") }
  let(:date) { Time.zone.today }
  let(:cash_params) do
    { fiscal_identity_token: token, cash_transaction: { user_bank_account_id: account.id, date:, description: "Receipt", price: -1000,
                                                        cash_installments_attributes: [ { number: 1, date:, price: -1000 } ] } }
  end
  let(:card_params) do
    { fiscal_identity_token: token, card_transaction: { user_card_id: card.id, date:, description: "Receipt", price: -1000,
                                                        card_installments_attributes: [ { number: 1, date:, price: -1000 } ] } }
  end

  before { sign_in user }

  it "checks across cash and card transactions and permits a confirmed repeat" do
    expect { post cash_transactions_path, params: cash_params }.to change(FiscalDocumentLink, :count).by(1)
    expect { post card_transactions_path, params: card_params }.not_to change(CardTransaction, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('name="fiscal_duplicate_confirmed"')

    expect do
      post card_transactions_path, params: card_params.merge(fiscal_duplicate_confirmed: "1")
    end.to change(FiscalDocumentLink, :count).by(1)
  end

  it "rejects a token issued to another user" do
    foreign = create(:user, :random)
    foreign_token = FiscalReceipts::IdentityToken.issue(user: foreign, access_key: key)
    expect { post cash_transactions_path, params: cash_params.merge(fiscal_identity_token: foreign_token) }.not_to change(CashTransaction, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "checks completed receipts only in the current financial context" do
    post cash_transactions_path, params: cash_params
    scenario = create(:context, user:)
    patch switch_context_path(scenario)

    expect { post cash_transactions_path, params: cash_params }.to change(FiscalDocumentLink, :count).by(1)
    expect(FiscalDocumentLink.pluck(:context_id)).to contain_exactly(user.main_context.id, scenario.id)
  end

  it "allows another transaction after deleting the linked transaction" do
    post cash_transactions_path, params: cash_params
    FiscalDocumentLink.sole.transactable.destroy!
    expect { post card_transactions_path, params: card_params }.to change(FiscalDocumentLink, :count).by(1)
  end
end
