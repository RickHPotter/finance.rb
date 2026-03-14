# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasExchanges, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:entity) { create(:entity, :random, user:) }

  let(:entity_transaction) do
    build(:entity_transaction,
          :random,
          entity:,
          transactable: build(:card_transaction,
                              :random,
                              user:,
                              user_card:,
                              price: -180,
                              date: Time.zone.today,
                              category_transactions: [],
                              entity_transactions: [],
                              card_installments: build_list(:card_installment, 1, price: -180) { |ci, i| ci.number = i + 1 }),
          price: 180,
          is_payer: true,
          exchanges: build_list(:exchange, 2, exchange_type: :monetary, price: 90, entity_transaction: nil) do |exchange, i|
            exchange.number = i + 1
            exchange.date = Time.zone.today + i.months
            exchange.month = exchange.date.month
            exchange.year = exchange.date.year
          end)
  end

  describe "[ concern behaviour ]" do
    it "sets status to pending when monetary exchanges are present" do
      entity_transaction.save!

      expect(entity_transaction.status).to eq("pending")
    end

    it "sets status to finished when all exchanges are non_monetary" do
      entity_transaction.exchanges.each { |exchange| exchange.exchange_type = :non_monetary }
      entity_transaction.save!

      expect(entity_transaction.status).to eq("finished")
    end

    it "updates exchanges_count on each exchange after save" do
      entity_transaction.save!

      expect(entity_transaction.exchanges.pluck(:exchanges_count).uniq).to eq([ 2 ])
    end
  end
end
