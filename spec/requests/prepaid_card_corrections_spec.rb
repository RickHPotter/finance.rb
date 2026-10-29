# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Prepaid card corrections", type: :request do
  let(:user) { create(:user, :random) }
  let(:user_card) { create(:user_card, :random, user:, card_kind: "prepaid") }
  let(:transaction) do
    CardTransaction.new(user:, context: user.main_context, user_card:, date: Time.zone.today, description: "Lunch", price: -1000).tap do |record|
      record.card_installments.first.price = -1000
      record.build_month_year
      record.save!
    end
  end

  before { sign_in user }

  it "changes a paid prepaid installment to unpaid" do
    installment = transaction.card_installments.first
    expect(installment).to be_paid

    patch card_transaction_path(transaction), params: { card_transaction: { card_installments_attributes: { "0" => { id: installment.id, paid: "0" } } } }

    expect(response).to have_http_status(:see_other)
    expect(installment.reload).not_to be_paid
    expect(transaction.reload).not_to be_paid
  end

  it "corrects a paid amount and paid state with historical confirmation" do
    installment = transaction.card_installments.first

    patch card_transaction_path(transaction), params: {
      card_transaction: { price: -1200, historical_correction_confirmation: "1",
                          card_installments_attributes: { "0" => { id: installment.id, paid: "0", price: -1200 } } }
    }

    expect(response).to have_http_status(:see_other)
    expect(transaction.reload.price).to eq(-1200)
    expect(installment.reload).to have_attributes(price: -1200, paid: false, cash_transaction_id: nil)
  end

  it "requires confirmation before correcting a paid amount" do
    installment = transaction.card_installments.first

    patch card_transaction_path(transaction), params: {
      card_transaction: { price: -1200, card_installments_attributes: { "0" => { id: installment.id, price: -1200 } } }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(transaction.reload.price).to eq(-1000)
    expect(installment.reload.price).to eq(-1000)
  end

  it "allows a planned prepaid purchase to be marked paid" do
    planned = CardTransaction.new(user:, context: user.main_context, user_card:, date: 1.month.from_now, description: "Planned", price: -1000)
    planned.card_installments.first.price = -1000
    planned.build_month_year
    planned.save!
    installment = planned.card_installments.first

    patch card_transaction_path(planned), params: { card_transaction: { card_installments_attributes: { "0" => { id: installment.id, paid: "1" } } } }

    expect(response).to have_http_status(:see_other)
    expect(installment.reload).to be_paid
    expect(planned.reload).to be_paid
  end
end
