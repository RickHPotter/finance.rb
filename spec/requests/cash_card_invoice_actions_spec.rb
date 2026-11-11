# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cash card invoice actions", type: :request do
  let(:user) { create(:user, :random) }
  let(:card) { create(:user_card, :random, user:) }
  let(:date) { Time.zone.today.next_month }
  let(:purchase) do
    create(:card_transaction, user:, user_card: card, context: user.main_context, date:, price: -1000,
                              card_installments: [ build(:card_installment, number: 1, date:, price: -1000, paid: false) ])
  end
  let(:invoice) { purchase.card_installments.first.cash_transaction }
  let(:installment) { invoice.cash_installments.first }
  let(:headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before { sign_in user }

  it "moves the invoice to the new month without paying it or changing the card billing cycle" do
    original_cycle = [ invoice.month, invoice.year ]
    new_date = (installment.date + 2.months).change(usec: 0)
    expect(installment).not_to be_paid

    patch change_date_cash_installment_path(installment), params: { cash_installment: { date: new_date.iso8601 } }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(installment.reload).to have_attributes(date: new_date, paid: false, month: new_date.month, year: new_date.year)
    expect(invoice.reload).to have_attributes(date: new_date, paid: false, month: original_cycle[0], year: original_cycle[1])
    expect(purchase.card_installments.first.reload).not_to be_paid
  end

  it "keeps a paid invoice paid when changing its date" do
    installment.update!(paid: true)
    patch change_date_cash_installment_path(installment), params: { cash_installment: { date: (installment.date + 1.day).iso8601 } }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(installment.reload).to be_paid
    expect(invoice.reload).to be_paid
  end

  it "does not expose the invoice date action for another user's installment" do
    foreign_user = create(:user, :random)
    sign_out user
    sign_in foreign_user
    patch change_date_cash_installment_path(installment), params: { cash_installment: { date: Time.zone.now.iso8601 } }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "rejects an invalid date without changing the invoice" do
    original = installment.date
    patch change_date_cash_installment_path(installment), params: { cash_installment: { date: "not-a-date" } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(installment.reload.date).to eq(original)
    expect(installment).not_to be_paid
  end

  it "does not allow this invoice action for an ordinary cash transaction" do
    ordinary = create(:cash_transaction, user:, context: user.main_context)
    patch change_date_cash_installment_path(ordinary.cash_installments.first),
          params: { cash_installment: { date: Time.zone.now.iso8601 } }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "renders separate date and advance actions for an unpaid invoice" do
    cycle = Date.new(invoice.year, invoice.month, 1)
    expect(card.references.find_by(context: user.main_context, month: invoice.month, year: invoice.year)).to be_present
    get month_year_cash_transactions_path, params: { month_year: cycle.strftime("%Y%m") }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("cashInstallmentDateModal_#{installment.id}")
    expect(response.body).to include(change_date_cash_installment_path(installment))
    expect(response.body).to include(CardTransaction.human_attribute_name(:pay_in_advance))
    expect(response.body).to include('name="return_to_cash_index"')
  end

  it "creates an advance from the cash index and refreshes the cash view" do
    cycle = Date.new(invoice.year, invoice.month, 1)
    window = Logic::CardAdvancePaymentWindow.new(user_card: card, context: user.main_context, month: cycle.month, year: cycle.year)
    expect(window).to be_available

    expect do
      post pay_in_advance_card_transactions_path,
           params: { return_to_cash_index: "1", index_context_json: { active_month_years: [ cycle.strftime("%Y%m").to_i ] }.to_json,
                     card_transaction: { user_card_id: card.id, month: cycle.month, year: cycle.year, date: window.maximum.iso8601, price: 200 } },
           headers: headers
    end.to change { user.main_context.card_transactions.count }.by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="center_container"', 'id="cash_transactions"')
    expect(user.main_context.card_transactions.order(:id).last.advance_cash_transaction.price).to eq(-200)
    expect(installment.reload).not_to be_paid
  end
end
