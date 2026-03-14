# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashInstallments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:installment_date) { Time.zone.local(2026, 3, 10, 12, 0, 0) }

  before { sign_in user }

  describe "[ #pay ]" do
    it "marks the installment as paid and splits the remainder when the paid amount is smaller" do
      cash_transaction = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(
            :cash_installment,
            number: 1,
            date: installment_date,
            month: 3,
            year: 2026,
            price: 1000,
            paid: false
          )
        ]
      )
      cash_installment = cash_transaction.cash_installments.first

      expect do
        patch pay_cash_installment_path(cash_installment), params: {
          cash_installment: {
            date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
            price: 600
          }
        }, headers: turbo_stream_headers
      end.to change(CashInstallment, :count).by(1)

      cash_installment.reload
      remainder = cash_transaction.cash_installments.where.not(id: cash_installment.id).order(:number).last

      expect(cash_installment).to be_paid
      expect(cash_installment.price).to eq(600)
      expect(cash_installment.date.to_date).to eq(Date.new(2026, 3, 12))
      expect(remainder.price).to eq(400)
      expect(remainder.date.to_date).to eq(Date.new(2026, 3, 11))
    end
  end

  describe "[ #pay_multiple ]" do
    it "marks all selected installments as paid with the chosen date" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      post pay_multiple_cash_installments_path, params: {
        ids: [ first.id, second.id ],
        cash_installment: {
          date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first.reload).to be_paid
      expect(second.reload).to be_paid
      expect(first.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(second.date.to_date).to eq(Date.new(2026, 3, 20))
    end
  end

  describe "[ #transfer_multiple ]" do
    it "moves all selected installments to the chosen reference month" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      post transfer_multiple_cash_installments_path, params: {
        ids: [ first.id, second.id ],
        reference_date: "2026-05",
        cash_installment: {
          date: Time.zone.local(2026, 5, 2, 9, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first.reload.month).to eq(5)
      expect(first.year).to eq(2026)
      expect(second.reload.month).to eq(5)
      expect(second.year).to eq(2026)
      expect(first.date.to_date).to eq(Date.new(2026, 5, 2))
      expect(second.date.to_date).to eq(Date.new(2026, 5, 2))
      expect(first).not_to be_paid
      expect(second).not_to be_paid
    end
  end
end
