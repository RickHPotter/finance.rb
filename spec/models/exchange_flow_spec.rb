# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CardTransactionFlow', class: CardTransaction, type: :model do
  let!(:ct_with_categories) { FactoryBot.create(:card_transaction, :random, :with_category_transactions) }
  let!(:ct_with_entity_transactions) { FactoryBot.create(:card_transaction, :random, :with_entity_transactions) }
  let!(:entity_transaction) { ct_with_entity_transactions.entity_transactions.first }
  let!(:exchange) { entity_transaction.exchanges.first }

  let!(:category_transaction_attributes) do
    [{
      category: FactoryBot.create(:category, :random, user: ct_with_categories.user),
      transactable: ct_with_categories
    }]
  end

  let!(:entity_transaction_attributes) do
    [{
      entity: FactoryBot.create(:entity, :random, user: ct_with_entity_transactions.user),
      transactable: ct_with_entity_transactions,
      is_payer: false
    }]
  end

  let!(:exchange_attributes) do
    [{ exchange_type: :monetary, price: 0.11 }]
  end

  shared_examples 'paying entity_transactions with Exchange category' do
    it 'creates the corresponding entity_transactions' do
      expect(ct_with_entity_transactions.entities).to be_present
      expect(ct_with_entity_transactions.paying_entities).to be_present
      expect(ct_with_entity_transactions.categories.pluck(:category_name)).to include('Exchange')
    end
  end

  shared_examples 'no paying entity_transactions and without Exchange category' do
    it 'creates the corresponding entity_transactions' do
      expect(ct_with_entity_transactions.entities).to be_empty
      expect(ct_with_entity_transactions.paying_entities).to be_empty
      expect(ct_with_entity_transactions.categories.pluck(:category_name)).to_not include('Exchange')
    end
  end

  shared_examples 'category Exchange on the transactable and Exchange Return on the MoneyTransaction' do
    it 'categories are set correctly for the beginning of the flow (transactable) and end (money_transaction) ' do
      expect(exchange.entity_transaction.transactable.categories.pluck(:category_name)).to include('Exchange')
      expect(exchange.money_transaction.categories.pluck(:category_name)).to include('Exchange Return')
    end
  end

  describe '[ business logic ]' do
    # category_transactions
    #
    context '( card_transaction creation with category_transaction_attributes )' do
      it 'creates the corresponding category_transaction' do
        expect(ct_with_categories.custom_categories.count).to eq(1)
      end
    end

    context '( card_transaction with category_transactions updates through category_transaction_attributes )' do
      before { ct_with_categories.update(category_transaction_attributes: []) }

      it 'destroys the existing category_transactions when emptying category_transaction_attributes' do
        expect(ct_with_categories.custom_categories).to be_empty
      end

      it 'destroys the existing category_transactions and then creates them again' do
        ct_with_categories.update(category_transaction_attributes:)

        expect(ct_with_categories.custom_categories).to_not be_empty
      end
    end

    # entity_transactions
    #
    context '( card_transaction creation with entity_transaction_attributes )' do
      include_examples 'paying entity_transactions with Exchange category'
    end

    context '( card_transaction creation entity_transactions updates through entity_transaction_attributes )' do
      before { ct_with_entity_transactions.update(entity_transaction_attributes: []) }

      include_examples 'no paying entity_transactions and without Exchange category'

      it 'destroys the existing entity_transactions and then creates them again' do
        ct_with_entity_transactions.update(entity_transaction_attributes:)

        expect(ct_with_entity_transactions.entities).to be_present
        expect(ct_with_entity_transactions.paying_entities).to be_empty
        expect(ct_with_entity_transactions.categories.pluck(:category_name)).to_not include('Exchange')
      end
    end

    # exchanges
    #
    context '( card_transaction creation with entity_transaction_attributes with exchange_attributes )' do
      it 'creates the corresponding exchange' do
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction with exchanges under updates through exchange_attributes )' do
      before { entity_transaction.update(exchange_attributes: exchange_attributes * 2) }

      it 'updates the amount of exchanges to two' do
        expect(entity_transaction.exchanges.count).to eq(2)
      end

      it 'updates the amount of exchanges to two then back to one' do
        entity_transaction.update(exchange_attributes:)
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction with exchanges under updates through is_payer )' do
      before { entity_transaction.update(is_payer: false) }

      it 'destroys the amount of existing exchanges' do
        expect(entity_transaction.exchanges).to be_empty
      end

      it 'creates exchanges after updating is_payer again' do
        entity_transaction.update(is_payer: true, exchange_attributes: exchange_attributes * 2)

        expect(entity_transaction.exchanges).to be_present
      end
    end

    context '( exchange creation with exchange_type monetary )' do
      before { exchange.monetary! }

      include_examples 'category Exchange on the transactable and Exchange Return on the MoneyTransaction'

      it 'generates a money_transaction' do
        expect(exchange.money_transaction).to_not be(nil)
      end

      it 'generates no money_transaction after another update to non_monetary' do
        exchange.non_monetary!
        expect(exchange.money_transaction).to be(nil)
      end
    end

    context '( exchange switching exchange_type to non_monetary )' do
      before { exchange.non_monetary! }

      it 'generates no money_transaction' do
        expect(exchange.money_transaction).to be(nil)
        expect(exchange.entity_transaction.finished?).to be(true)
      end

      it 'generates a money_transaction after another update to monetary' do
        exchange.monetary!
        expect(exchange.money_transaction).to_not be(nil)
        expect(exchange.entity_transaction.pending?).to be(true)
      end
    end

    # FIXME: hello, bitches
    # money_transaction
    #
    context '( money_transaction creation by default due to monetary exchange )' do
    end
  end
end
