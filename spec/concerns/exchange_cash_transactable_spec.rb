# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExchangeCashTransactable, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:category) { create(:category, :random, user:) }
  let(:exchange_category) { user.built_in_category("EXCHANGE") }
  let(:exchange_return_category) { user.built_in_category("EXCHANGE RETURN") }
  let(:entity) { create(:entity, :random, user:) }

  let(:exchangable_card_transaction) do
    build(:card_transaction,
          :random,
          user:, user_card:, price: -180, date: Time.zone.today,
          card_installments: build_list(:card_installment, 2, price: -90) { |ci, i| ci.number = i + 1 },
          category_transactions: build_list(:category_transaction, 1, :random, category: exchange_category, transactable: nil),
          entity_transactions: build_list(:entity_transaction, 1,
                                          :random,
                                          entity:, price: 180, is_payer: true,
                                          exchanges: build_list(:exchange, 2, exchange_type: :monetary, price: 90, entity_transaction: nil) do |exchange, i|
                                            exchange.number = i + 1
                                            exchange.date = Time.zone.today + i.months
                                          end,
                                          transactable: nil))
  end

  let(:non_exchangable_card_transaction) do
    build(:card_transaction,
          :random,
          user:, user_card:, price: -180, date: Time.zone.today,
          card_installments: build_list(:card_installment, 2, price: -90) { |ci, i| ci.number = i + 1 },
          category_transactions: build_list(:category_transaction, 1, :random, category:, transactable: nil),
          entity_transactions: build_list(:entity_transaction, 1,
                                          :random,
                                          entity:, price: -180, is_payer: false,
                                          exchanges: [],
                                          transactable: nil))
  end

  def validate(card_transaction, price, count)
    exchanges = card_transaction.entity_transactions.first.exchanges.reload
    shared_cash_transaction = shared_projection_cash_transaction(card_transaction)

    expect(exchanges.sum(:price)).to eq(price)
    expect(shared_cash_transaction.price).to eq(price)
    expect(shared_cash_transaction.cash_installments.count).to eq(count)
    expect(shared_cash_transaction.cash_installments.sum(:price)).to eq(price)
  end

  def shared_projection_cash_transaction(card_transaction)
    cash_transactions = card_transaction.entity_transactions.first.exchanges.reload.filter_map(&:cash_transaction).map(&:reload)

    expect(cash_transactions.map(&:id).uniq.count).to eq(1)

    cash_transactions.first
  end

  describe "[ concern behaviour ]" do
    context "( creating exchangable card_transaction )" do
      it "attaches an Exchange when categories.include?(exchange_category) &&  entity_transaction.is_payer" do
        exchangable_card_transaction.save

        expect(exchangable_card_transaction.entity_transactions.first.exchanges).to be_present
      end
    end

    context "( creating non_exchangable card_transaction )" do
      it "does not attach an Exchange when categories.include?(exchange_category) && !entity_transaction.is_payer" do
        non_exchangable_card_transaction.save

        expect(non_exchangable_card_transaction.entity_transactions.first.exchanges).to be_empty
      end

      it "does not attach an EXCHANGE RETURN CashTransaction when exchange.non_monetary?" do
        non_exchangable_card_transaction.entity_transactions.first.exchanges = exchangable_card_transaction.entity_transactions.first.exchanges
        non_exchangable_card_transaction.entity_transactions.first.exchanges.each { |exchange| exchange.exchange_type = :non_monetary }
        non_exchangable_card_transaction.save

        cash_transactions = non_exchangable_card_transaction.entity_transactions.first.exchanges.map(&:cash_transaction).compact

        expect(cash_transactions).to be_empty
      end

      it "does not raise when a new standalone monetary exchange resolves to zero cash transaction price" do
        exchange = build(:exchange, entity_transaction: build(:entity_transaction, transactable: build(:cash_transaction, user:)), exchange_type: :monetary, price: 0)

        expect { exchange.save! }.not_to raise_error
        expect(exchange.cash_transaction).to be_nil
      end
    end

    context "( updating exchangable card_transaction )" do
      before do
        exchangable_card_transaction.save
      end

      it "updates price accordingly" do
        exchangable_card_transaction.price = -300
        exchangable_card_transaction.entity_transactions.first.price = 300
        exchangable_card_transaction.entity_transactions.first.exchanges.each { |exchange| exchange.price = 150 }
        exchangable_card_transaction.save

        expect(exchangable_card_transaction.entity_transactions.first.exchanges.sum(:price)).to eq(300)
      end

      it "attaches one more mirrored EXCHANGE RETURN installment when exchanges increases by one" do
        new_exchange = exchangable_card_transaction.entity_transactions.first.exchanges.last.dup
        new_exchange.number += 1
        new_exchange.date = new_exchange.date + 1.month

        if new_exchange.month == 12
          new_exchange.month = 1
          new_exchange.year += 1
        else
          new_exchange.month += 1
        end

        exchangable_card_transaction.entity_transactions.first.exchanges << new_exchange
        exchangable_card_transaction.entity_transactions.first.exchanges.each { |exchange| exchange.price = 60 }
        exchangable_card_transaction.save

        validate(exchangable_card_transaction, 180, 3)
      end

      it "detaches one mirrored EXCHANGE RETURN installment when exchanges decreases by one" do
        exchangable_card_transaction.entity_transactions.first.exchanges.first.price = 180
        exchangable_card_transaction.entity_transactions.first.exchanges.second.mark_for_destruction
        exchangable_card_transaction.save

        validate(exchangable_card_transaction, 180, 1)
      end

      it "detaches and removes Exchanges when categories.exclude?(exchange_category) || !entity_transaction.is_payer" do
        exchangable_card_transaction.entity_transactions = non_exchangable_card_transaction.entity_transactions
        exchangable_card_transaction.save

        expect(exchangable_card_transaction.entity_transactions.first.exchanges).to be_empty
      end

      it "detaches and removes an EXCHANGE RETURN CashTransaction when exchange.non_monetary?" do
        cash_transaction_ids_to_be_deleted = exchangable_card_transaction.entity_transactions.first.exchanges.map(&:cash_transaction_id)

        exchangable_card_transaction.entity_transactions.first.exchanges.each(&:non_monetary!)
        exchangable_card_transaction.save

        cash_transactions = exchangable_card_transaction.entity_transactions.first.exchanges.reload.map(&:cash_transaction).compact

        expect(cash_transactions).to be_empty
        expect(CashTransaction.where(id: cash_transaction_ids_to_be_deleted)).to be_empty
      end
    end

    context "( updating non_exchangable card_transaction )" do
      before do
        non_exchangable_card_transaction.save

        non_exchangable_card_transaction.category_transactions = exchangable_card_transaction.category_transactions
        non_exchangable_card_transaction.entity_transactions   = exchangable_card_transaction.entity_transactions
      end

      it "attaches Exchanges when categories.include?(exchange_category) && entity_transaction.is_payer && exchange.non_monetary?" do
        non_exchangable_card_transaction.entity_transactions.first.exchanges.each { |exchange| exchange.exchange_type = :non_monetary }
        non_exchangable_card_transaction.reload

        expect(non_exchangable_card_transaction.entity_transactions.first.exchanges).to be_present
      end

      it "attaches EXCHANGE RETURN CashTransactions when categories.include?(exchange_category) && entity_transaction.is_payer && exchange.monetary?" do
        non_exchangable_card_transaction.entity_transactions.first.exchanges.each { |exchange| exchange.exchange_type = :monetary }
        non_exchangable_card_transaction.reload

        expect(non_exchangable_card_transaction.categories).to include(exchange_category)
        validate(non_exchangable_card_transaction, 180, 2)
      end
    end

    context "( destroying exchangable card_transaction )" do
      before { exchangable_card_transaction.save }

      it "ceases to exist" do
        entity_transactions_ids = exchangable_card_transaction.entity_transactions.map(&:id)
        exchanges_ids = exchangable_card_transaction.entity_transactions.first.exchanges.map(&:id)
        cash_transactions_ids = exchangable_card_transaction.entity_transactions.first.exchanges.map(&:cash_transaction_id)

        exchangable_card_transaction.destroy

        expect(exchangable_card_transaction).to be_destroyed
        expect(EntityTransaction.where(id: entity_transactions_ids)).to be_empty
        expect(Exchange.where(id: exchanges_ids)).to be_empty
        expect(CashTransaction.where(id: cash_transactions_ids)).to be_empty
      end
    end
  end
end
