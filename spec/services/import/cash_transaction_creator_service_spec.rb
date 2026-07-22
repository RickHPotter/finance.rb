# frozen_string_literal: true

require "rails_helper"

RSpec.describe Import::CashTransactionCreatorService do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card: create(:card, :random, bank:)) }
  let(:main_service) do
    instance_double(
      Import::MainService,
      hash_cash_collection: [],
      user:,
      user_id: user.id,
      find_or_create_user_bank: user_bank_account,
      find_or_create_user_card: user_card,
      create_category_and_entity_transactions: [ [], [] ]
    )
  end
  let(:service) { described_class.new(main_service) }

  describe "[ context isolation ]" do
    it "updates only the main-context card payment match" do
      category = user.built_in_category("CARD PAYMENT")
      main_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        date: Date.new(2026, 3, 1),
        month: 3,
        year: 2026,
        price: -1000
      )
      main_transaction.categories = [ category ]
      main_transaction.save!

      derived_context = create(:context, user:, name: "Import Isolation", source_context: user.main_context)
      derived_transaction = create(
        :cash_transaction,
        user:,
        context: derived_context,
        user_bank_account:,
        user_card:,
        date: Date.new(2026, 3, 2),
        month: 3,
        year: 2026,
        price: -1000
      )
      derived_transaction.categories = [ category ]
      derived_transaction.save!

      service.send(
        :add_card_payment,
        user,
        { month: 3, year: 2026, date: Date.new(2026, 3, 12) },
        { month: 3, year: 2026, price: -1000, user_card_id: user_card.id, categories: { category_name: "CARD PAYMENT" } }
      )

      expect(main_transaction.reload.date.to_date).to eq(Date.new(2026, 3, 12))
      expect(derived_transaction.reload.date.to_date).to eq(Date.new(2026, 3, 2))
      expect(user_card.references.find_by(context: user.main_context, month: 3, year: 2026)).to be_present
      expect(user_card.references.find_by(context: derived_context, month: 3, year: 2026)).to be_nil
    end

    it "looks for card advances only inside the main context" do
      main_context = user.main_context
      scoped_relation = instance_double(ActiveRecord::Relation)
      card_installment = instance_double(CardInstallment, update_columns: true)
      card_installments = instance_double(ActiveRecord::Associations::CollectionProxy, first: card_installment)
      main_transaction = instance_double(CardTransaction, update: true, card_installments:)
      matched_transactions = instance_double(ActiveRecord::Relation, empty?: false, one?: true, first: main_transaction)

      expect(user).not_to receive(:card_transactions)
      allow(user).to receive(:main_context).and_return(main_context)
      expect(main_context).to receive(:card_transactions).and_return(scoped_relation)
      expect(scoped_relation).to receive(:joins).with(:categories).and_return(scoped_relation)
      expect(scoped_relation).to receive(:where).with(
        hash_including(
          month: 3,
          year: 2026,
          price: -1000,
          user_card_id: user_card.id,
          categories: { category_name: "CARD ADVANCE" }
        )
      ).and_return(matched_transactions)
      expect(main_transaction).to receive(:update).with(date: Date.new(2026, 3, 15), imported: true)
      expect(card_installment).to receive(:update_columns).with({ date: Date.new(2026, 3, 15) })

      service.send(
        :add_card_advance,
        user,
        { month: 3, year: 2026, date: Date.new(2026, 3, 15) },
        { month: 3, year: 2026, price: 1000, user_card_id: user_card.id, categories: { category_name: "CARD ADVANCE" } }
      )
    end
  end
end
