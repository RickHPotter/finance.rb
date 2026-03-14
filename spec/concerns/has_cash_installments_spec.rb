# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasCashInstallments, type: :concern do
  describe "[ concern behaviour ]" do
    it "updates cash_installments_count on each installment after save" do
      cash_transaction = build(
        :cash_transaction,
        :random,
        date: Time.zone.today,
        category_transactions: [],
        entity_transactions: [],
        cash_installments: build_list(:cash_installment, 2, price: 100) { |ci, i| ci.number = i + 1 }
      )

      cash_transaction.save!

      expect(cash_transaction.cash_installments.pluck(:cash_installments_count).uniq).to eq([ 2 ])
    end

    it "remembers original_installments when cash_installments are reassigned" do
      cash_transaction = create(
        :cash_transaction,
        :random,
        category_transactions: [],
        entity_transactions: [],
        cash_installments: build_list(:cash_installment, 2, price: 100) { |ci, i| ci.number = i + 1 }
      )

      original_installments = cash_transaction.cash_installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }

      cash_transaction.cash_installments = [ build(:cash_installment, price: 200, number: 1) ]

      expect(cash_transaction.original_installments).to eq(original_installments)
    end
  end
end
