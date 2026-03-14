# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::CashInstallments do # rubocop:disable Metrics/BlockLength
  describe ".fetch_cash_installments" do # rubocop:disable Metrics/BlockLength
    let(:user) { create(:user) }
    let(:bank) { create(:bank, :random) }
    let(:user_bank_account) { create(:user_bank_account, user: user, bank: bank) }

    # Create transactions with specific dates to ensure they fall in the same month/year
    let(:date) { Date.new(2023, 10, 15) }

    let!(:cash_transaction1) do
      create(:cash_transaction, user: user, user_bank_account: user_bank_account, date: date, cash_installments_count: 1)
    end

    let!(:cash_transaction2) do
      create(:cash_transaction, user: user, user_bank_account: user_bank_account, date: date, cash_installments_count: 1)
    end

    let(:installment1) { cash_transaction_1.cash_installments.first }
    let(:installment2) { cash_transaction_2.cash_installments.first }
    let(:year) { date.year }
    let(:month) { date.month }

    before do
      # Double check installments have correct date/month/year
      # The factory might derive them from transaction date
      installment_1.update!(date: date, year: year, month: month)
      installment_2.update!(date: date, year: year, month: month)
    end

    it "filters by cash_installment_ids" do
      options = {
        conditions: {},
        search_term_condition: nil,
        ids: [ installment1.id ]
      }

      result = described_class.fetch_cash_installments(user, month, year, options)

      expect(result).to include(installment_1)
      expect(result).not_to include(installment_2)
    end

    it "returns all if ids are not provided" do
      options = {
        conditions: {},
        search_term_condition: nil
      }

      result = described_class.fetch_cash_installments(user, month, year, options)

      expect(result).to include(installment_1)
      expect(result).to include(installment_2)
    end
  end
end
