# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasCardInstallments, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }

  describe "[ concern behaviour ]" do
    it "updates card_installments_count on each installment after save" do
      card_transaction = build(
        :card_transaction,
        :random,
        user:,
        user_card:,
        price: -200,
        date: Time.zone.today,
        category_transactions: [],
        entity_transactions: [],
        card_installments: build_list(:card_installment, 2, price: -100) { |ci, i| ci.number = i + 1 }
      )

      card_transaction.save!

      expect(card_transaction.card_installments.pluck(:card_installments_count).uniq).to eq([ 2 ])
    end

    it "remembers original_installments when card_installments are reassigned" do
      card_transaction = create(
        :card_transaction,
        :random,
        user:,
        user_card:,
        category_transactions: [],
        entity_transactions: [],
        card_installments: build_list(:card_installment, 2, price: -100) { |ci, i| ci.number = i + 1 }
      )

      original_installments = card_transaction.card_installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }

      card_transaction.card_installments_attributes = [
        {
          number: 1,
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          price: -200,
          paid: false
        }
      ]

      expect(card_transaction.original_installments).to eq(original_installments)
    end
  end
end
