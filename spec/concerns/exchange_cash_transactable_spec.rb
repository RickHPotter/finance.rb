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
  let(:user_bank_account) { create(:user_bank_account, :random, user:) }

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

      it "fills the standalone mirrored EXCHANGE RETURN reference with the source transactable" do
        shared_cash_transaction = shared_projection_cash_transaction(exchangable_card_transaction)

        expect(shared_cash_transaction.reference_transactable).to eq(exchangable_card_transaction)
      end

      it "keeps the standalone mirrored EXCHANGE RETURN description equal to the source description" do
        shared_cash_transaction = shared_projection_cash_transaction(exchangable_card_transaction)

        expect(shared_cash_transaction.description).to eq(exchangable_card_transaction.description)
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

      it "restores a missing standalone mirrored EXCHANGE RETURN reference on sync" do
        shared_cash_transaction = shared_projection_cash_transaction(exchangable_card_transaction)
        shared_cash_transaction.update_columns(reference_transactable_type: nil, reference_transactable_id: nil)
        exchange = exchangable_card_transaction.entity_transactions.first.exchanges.first
        exchange.update!(price: 91, starting_price: 91)

        expect(shared_cash_transaction.reload.reference_transactable).to eq(exchangable_card_transaction)
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

    context "( updating standalone exchange with replayed paid-state rows )" do
      it "rebuilds the linked EXCHANGE RETURN projection from the in-memory sibling exchange set" do
        exchange_transaction = create(
          :cash_transaction,
          user:,
          context: user.main_context,
          user_bank_account: user_bank_account,
          description: "Projection replay sync",
          date: Time.zone.local(2026, 6, 26, 0, 0, 0),
          month: 6,
          year: 2026,
          price: 2_302,
          category_transactions_attributes: [
            { category_id: exchange_category.id }
          ],
          entity_transactions_attributes: [
            {
              entity_id: entity.id,
              is_payer: true,
              price: -2_302,
              price_to_be_returned: -2_302,
              exchanges_count: 3,
              exchanges_attributes: [
                { number: 1, price: -500, date: Time.zone.local(2026, 6, 26, 16, 0, 0), month: 6, year: 2026 },
                { number: 2, price: -651, date: Time.zone.local(2026, 6, 27, 14, 0, 0), month: 6, year: 2026 },
                { number: 3, price: -1_151, date: Time.zone.local(2026, 6, 28, 0, 0, 0), month: 6, year: 2026 }
              ]
            }
          ],
          cash_installments_attributes: [
            { number: 1, price: 2_302, date: Time.zone.local(2026, 6, 26, 0, 0, 0), month: 6, year: 2026, paid: true }
          ]
        )

        exchange_return = create(
          :cash_transaction,
          user:,
          context: user.main_context,
          user_bank_account: user_bank_account,
          reference_transactable: exchange_transaction,
          description: exchange_transaction.description,
          date: Time.zone.local(2026, 6, 26, 16, 0, 0),
          month: 6,
          year: 2026,
          price: -2_302,
          category_transactions_attributes: [
            { category_id: exchange_return_category.id }
          ],
          entity_transactions_attributes: [
            { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
          ],
          cash_installments_attributes: [
            { number: 1, price: -500, date: Time.zone.local(2026, 6, 26, 16, 0, 0), month: 6, year: 2026, paid: false },
            { number: 2, price: -651, date: Time.zone.local(2026, 6, 27, 14, 0, 0), month: 6, year: 2026, paid: false },
            { number: 3, price: -1_151, date: Time.zone.local(2026, 6, 28, 0, 0, 0), month: 6, year: 2026, paid: false }
          ]
        )
        exchange_transaction.entity_transactions.first.exchanges.update_all(cash_transaction_id: exchange_return.id)

        exchange_transaction.reload
        entity_transaction = exchange_transaction.entity_transactions.first
        exchanges = entity_transaction.exchanges.order(:number).to_a
        assignable_attributes = {
          description: exchange_transaction.description,
          price: 2_302,
          date: Time.zone.local(2026, 6, 26, 0, 0, 0),
          month: 6,
          year: 2026,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          reference_transactable_type: "CashTransaction",
          reference_transactable_id: exchange_transaction.reference_transactable_id,
          category_transactions_attributes: exchange_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          cash_installments_attributes: [
            {
              id: exchange_transaction.cash_installments.first.id,
              number: 1,
              date: Time.zone.local(2026, 6, 26, 0, 0, 0),
              month: 6,
              year: 2026,
              price: 2_302,
              paid: true
            }
          ],
          entity_transactions_attributes: [
            {
              id: entity_transaction.id,
              entity_id: entity.id,
              is_payer: true,
              price: -2_302,
              price_to_be_returned: -2_302,
              exchanges_count: 5,
              exchanges_attributes: [
                {
                  id: exchanges[0].id,
                  number: 1,
                  date: Time.zone.local(2026, 6, 26, 16, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -500,
                  paid: true,
                  bound_type: "standalone",
                  exchange_type: "monetary"
                },
                {
                  id: exchanges[1].id,
                  number: 2,
                  date: Time.zone.local(2026, 6, 26, 19, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -51,
                  paid: true,
                  bound_type: "standalone",
                  exchange_type: "monetary"
                },
                {
                  id: exchanges[2].id,
                  number: 3,
                  date: Time.zone.local(2026, 6, 26, 20, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -300,
                  paid: true,
                  bound_type: "standalone",
                  exchange_type: "monetary"
                },
                {
                  number: 4,
                  date: Time.zone.local(2026, 6, 27, 14, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -300,
                  paid: false,
                  bound_type: "standalone",
                  exchange_type: "monetary"
                },
                {
                  number: 5,
                  date: Time.zone.local(2026, 6, 28, 0, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -1_151,
                  paid: false,
                  bound_type: "standalone",
                  exchange_type: "monetary"
                }
              ]
            }
          ]
        }.with_indifferent_access

        sanitized_attributes = assignable_attributes.deep_dup
        sanitized_attributes[:entity_transactions_attributes].each do |entity_attributes|
          entity_attributes[:exchanges_attributes].each do |exchange_attributes|
            exchange_attributes.delete(:paid)
          end
        end

        exchange_transaction.edit_phase = true
        exchange_transaction.assign_attributes(sanitized_attributes)

        assignable_attributes[:entity_transactions_attributes].each do |submitted_entity_attributes|
          persisted_entity_transaction = exchange_transaction.entity_transactions.find { |record| record.id == submitted_entity_attributes[:id] }
          submitted_entity_attributes[:exchanges_attributes].each do |submitted_exchange_attributes|
            persisted_exchange = persisted_entity_transaction.exchanges.find do |record|
              record.id == submitted_exchange_attributes[:id] || record.number == submitted_exchange_attributes[:number]
            end
            next if persisted_exchange.blank?

            persisted_exchange.replay_paid_state = submitted_exchange_attributes[:paid]
          end
        end

        expect(exchange_transaction.save).to be(true)
        expect(exchange_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq(
          [
            [ -500, true ],
            [ -51, true ],
            [ -300, true ],
            [ -300, false ],
            [ -1_151, false ]
          ]
        )
      end
    end
  end
end
