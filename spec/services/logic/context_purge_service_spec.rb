# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ContextPurgeService do
  describe "#call" do
    let(:user) { create(:user) }
    let(:main_context) { user.main_context }
    let(:derived_context) { create(:context, user:, source_context: main_context, archived_at: Time.current) }
    let(:bank) { create(:bank, :random) }
    let(:user_bank_account) { create(:user_bank_account, user:, bank:) }
    let(:user_card) { create(:user_card, user:) }
    let(:main_category) { create(:category, :random, user:, category_name: "Main category") }
    let(:derived_category) { create(:category, :random, user:, category_name: "Derived category") }
    let(:main_entity) { create(:entity, :random, user:, entity_name: "Main entity") }
    let(:derived_entity) { create(:entity, :random, user:, entity_name: "Derived entity") }

    it "does not delete main-context entity/category rows when derived cash transaction ids match card transaction ids" do
      main_card_transaction, derived_cash_transaction = align_card_and_cash_transaction_ids
      main_card_transaction.categories = [ main_category ]
      main_card_transaction.entities = [ main_entity ]
      main_card_transaction.save!
      main_category_ids = main_card_transaction.reload.category_ids.sort
      main_entity_ids = main_card_transaction.entity_ids.sort
      main_category_transaction_count = CategoryTransaction.where(transactable: main_card_transaction).count
      main_entity_transaction_count = EntityTransaction.where(transactable: main_card_transaction).count

      derived_cash_transaction.categories = [ derived_category ]
      derived_cash_transaction.entities = [ derived_entity ]
      derived_cash_transaction.save!

      expect do
        described_class.new(context: derived_context, user:).call
      end.to change { Context.exists?(derived_context.id) }.from(true).to(false)

      expect(main_card_transaction.reload.category_ids.sort).to eq(main_category_ids)
      expect(main_card_transaction.entity_ids.sort).to eq(main_entity_ids)
      expect(CategoryTransaction.where(transactable: main_card_transaction).count).to eq(main_category_transaction_count)
      expect(EntityTransaction.where(transactable: main_card_transaction).count).to eq(main_entity_transaction_count)
    end

    it "does not delete main-context entity/category rows when derived card transaction ids match cash transaction ids" do
      main_cash_transaction, derived_card_transaction = align_cash_and_card_transaction_ids
      main_cash_transaction.categories = [ main_category ]
      main_cash_transaction.entities = [ main_entity ]
      main_cash_transaction.save!
      main_category_ids = main_cash_transaction.reload.category_ids.sort
      main_entity_ids = main_cash_transaction.entity_ids.sort
      main_category_transaction_count = CategoryTransaction.where(transactable: main_cash_transaction).count
      main_entity_transaction_count = EntityTransaction.where(transactable: main_cash_transaction).count

      derived_card_transaction.categories = [ derived_category ]
      derived_card_transaction.entities = [ derived_entity ]
      derived_card_transaction.save!

      expect do
        described_class.new(context: derived_context, user:).call
      end.to change { Context.exists?(derived_context.id) }.from(true).to(false)

      expect(main_cash_transaction.reload.category_ids.sort).to eq(main_category_ids)
      expect(main_cash_transaction.entity_ids.sort).to eq(main_entity_ids)
      expect(CategoryTransaction.where(transactable: main_cash_transaction).count).to eq(main_category_transaction_count)
      expect(EntityTransaction.where(transactable: main_cash_transaction).count).to eq(main_entity_transaction_count)
    end

    it "raises when the context does not belong to the provided user" do
      foreign_user = create(:user, :random)
      foreign_context = create(:context, user: foreign_user, source_context: foreign_user.main_context, archived_at: Time.current)

      expect do
        described_class.new(context: foreign_context, user:).call
      end.to raise_error(Logic::ContextPurgeService::UnauthorizedContextAccessError)
    end

    it "raises when main-context transactions still reference derived transactions" do
      derived_cash_transaction = create(:cash_transaction, user:, context: derived_context, user_bank_account:)
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: main_context,
        user_bank_account:,
        reference_transactable: derived_cash_transaction
      )

      expect do
        described_class.new(context: derived_context, user:).call
      end.to raise_error(Logic::ContextPurgeService::CrossContextDependencyError)

      expect(Context.exists?(derived_context.id)).to be(true)
      expect(main_cash_transaction.reload.reference_transactable).to eq(derived_cash_transaction)
    end

    it "rolls back the purge when the invariant guard fails after deletions" do
      create(:cash_transaction, user:, context: derived_context, user_bank_account:)
      service = described_class.new(context: derived_context, user:)

      allow(service).to receive(:ensure_main_context_unchanged!).and_raise(Logic::ContextPurgeService::InvariantViolation)

      expect do
        service.call
      end.to raise_error(Logic::ContextPurgeService::InvariantViolation)

      expect(Context.exists?(derived_context.id)).to be(true)
      expect(derived_context.cash_transactions.exists?).to be(true)
    end

    private

    def align_card_and_cash_transaction_ids
      main_card_transaction = create(:card_transaction, user:, context: main_context, user_card:)
      derived_cash_transaction = create(:cash_transaction, user:, context: derived_context, user_bank_account:)

      while main_card_transaction.id != derived_cash_transaction.id
        if main_card_transaction.id < derived_cash_transaction.id
          main_card_transaction = create(:card_transaction, user:, context: main_context, user_card:)
        else
          derived_cash_transaction = create(:cash_transaction, user:, context: derived_context, user_bank_account:)
        end
      end

      [ main_card_transaction, derived_cash_transaction ]
    end

    def align_cash_and_card_transaction_ids
      main_cash_transaction = create(:cash_transaction, user:, context: main_context, user_bank_account:)
      derived_card_transaction = create(:card_transaction, user:, context: derived_context, user_card:)

      while main_cash_transaction.id != derived_card_transaction.id
        if main_cash_transaction.id < derived_card_transaction.id
          main_cash_transaction = create(:cash_transaction, user:, context: main_context, user_bank_account:)
        else
          derived_card_transaction = create(:card_transaction, user:, context: derived_context, user_card:)
        end
      end

      [ main_cash_transaction, derived_card_transaction ]
    end
  end
end
