# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::CashInstallments do
  describe ".fetch_cash_installments" do
    let(:user) { create(:user) }
    let(:bank) { create(:bank, :random) }
    let(:user_bank_account) { create(:user_bank_account, user:, bank:) }
    let(:date) { Date.new(2023, 10, 15) }

    let!(:cash_transaction_one) do
      create(:cash_transaction, user:, user_bank_account:, date:, cash_installments_count: 1)
    end

    let!(:cash_transaction_two) do
      create(:cash_transaction, user:, user_bank_account:, date:, cash_installments_count: 1)
    end

    let!(:cash_transaction_three) do
      create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date:,
        cash_installments: build_list(:cash_installment, 2, price: 1000) do |installment, index|
          installment.assign_attributes(number: index + 1)
        end
      )
    end

    let!(:installment_one) { cash_transaction_one.cash_installments.first }
    let!(:installment_two) { cash_transaction_two.cash_installments.first }
    let!(:installment_three_first) { cash_transaction_three.cash_installments.find_by(number: 1) }
    let!(:installment_three_second) { cash_transaction_three.cash_installments.find_by(number: 2) }

    let(:year) { date.year }
    let(:month) { date.month }

    before do
      [ installment_one, installment_two, installment_three_first, installment_three_second ].each do |installment|
        installment.update!(date:, year:, month:)
      end
    end

    it "filters by cash_installment_ids" do
      options = {
        conditions: {},
        search_term_condition: nil,
        ids: [ installment_one.id ]
      }

      result = described_class.fetch_cash_installments(user, month, year, options)

      expect(result).to contain_exactly(installment_one)
    end

    it "filters by installment number range" do
      options = {
        conditions: { number: 1..1 },
        search_term_condition: nil
      }

      result = described_class.fetch_cash_installments(user, month, year, options)

      expect(result).to contain_exactly(installment_one, installment_two, installment_three_first)
      expect(result).not_to include(installment_three_second)
    end

    it "returns all if ids are not provided" do
      options = {
        conditions: {},
        search_term_condition: nil
      }

      result = described_class.fetch_cash_installments(user, month, year, options)

      expect(result).to contain_exactly(installment_one, installment_two, installment_three_first, installment_three_second)
    end
  end
end
