# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ContextCloneService do
  describe "#call" do
    it "accepts an explicit scenario key for the cloned context" do
      user = create(:user)
      source_context = create(:context, user:, name: "Scenario")

      cloned_context = described_class.new(
        source_context:,
        name: "Scenario clone",
        scenario_key: "shared-scenario"
      ).call

      expect(cloned_context.scenario_key).to eq("shared-scenario")
    end

    it "records callback-bypassing financial clones as one projection operation" do
      user = create(:user, :random)
      source_context = create(:context, user:, name: "Audited source")
      create(:subscription, user:, context: source_context, description: "Audited subscription")
      create(:budget, user:, context: source_context, description: "Audited budget")

      cloned_context = Audit::Operation.run(actor: user, context: source_context, source: :web) do
        described_class.new(source_context:, name: "Audited clone").call
      end

      versions = AuditVersion.where(context_id: cloned_context.id)
      expect(versions.where(event: :create).pluck(:item_type)).to contain_exactly("Subscription", "Budget")
      expect(versions.pluck(:mutation_source).uniq).to eq([ "projection_sync" ])
      expect(versions.pluck(:owner_id).uniq).to eq([ user.id ])
    end

    it "remaps Piggy Bank links and valuations inside the cloned context" do
      user = create(:user, :random)
      source_context = create(:context, user:, name: "Piggy source")
      account = create(:user_bank_account, :random, user:)
      entity = create(:entity, :random, user:)
      source = build(
        :cash_transaction,
        user:,
        context: source_context,
        user_bank_account: account,
        description: "Emergency reserve",
        price: -5_000,
        cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Time.zone.now) ],
        category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
        entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
        piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
      )
      source.save!
      valuation = create(
        :investment,
        user:,
        context: source_context,
        user_bank_account: account,
        investment_type: create(:investment_type, :random),
        description: "Reserve profit",
        price: 500,
        date: Time.zone.today,
        piggy_bank_return_cash_transaction: source.piggy_bank.return_cash_transaction
      )

      cloned_context = described_class.new(source_context:, name: "Piggy clone").call
      cloned_source = cloned_context.cash_transactions.joins(:categories).find_by!(categories: { category_name: "PIGGY BANK" })
      cloned_return = cloned_source.piggy_bank.return_cash_transaction
      cloned_valuation = cloned_context.investments.find_by!(description: valuation.description)

      expect(cloned_source.piggy_bank.id).not_to eq(source.piggy_bank.id)
      expect(cloned_return.context).to eq(cloned_context)
      expect(cloned_return.id).not_to eq(source.piggy_bank.return_cash_transaction_id)
      expect(cloned_valuation.piggy_bank_return_cash_transaction).to eq(cloned_return)
      expect(AuditVersion.where(item: cloned_source.piggy_bank, event: :create)).to exist
    end

    it "clones a context financial snapshot into a new derived context" do
      user = create(:user)
      source_context = create(:context, user:, name: "What If")
      user_card = create(:user_card, user:)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      category = create(:category, :random, user:)
      entity = create(:entity, :random, user:)
      investment_type = create(:investment_type)

      create(:reference, context: source_context, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12),
                         reference_closing_date: Date.new(2026, 3, 5))

      budget = create(:budget, user:, context: source_context, month: 3, year: 2026, value: -10_000, remaining_value: -8_000)
      budget.categories = [ category ]
      budget.entities = [ entity ]
      budget.save!

      subscription = create(:subscription, user:, context: source_context, description: "Gym")
      subscription.categories = [ category ]
      subscription.entities = [ entity ]
      subscription.save!

      standalone_reference = create(:cash_transaction, user:, context: user.main_context, user_bank_account:)
      cash_transaction = create(:cash_transaction, user:, context: source_context, user_bank_account:, subscription:)
      cash_transaction.categories = [ category ]
      cash_transaction.entities = [ entity ]
      cash_transaction.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: standalone_reference.id)

      card_transaction = create(:card_transaction, user:, context: source_context, user_card:, subscription:)
      card_transaction.categories = [ category ]
      card_transaction.entities = [ entity ]
      card_transaction.save!

      investment = create(:investment, user:, context: source_context, user_bank_account:, investment_type:)

      cloned_context = described_class.new(
        source_context:,
        name: "What If Clone"
      ).call

      expect(cloned_context).to be_persisted
      expect(cloned_context.source_context).to eq(source_context)
      expect(cloned_context).not_to be_main
      expect(cloned_context.cloned_at).to be_present

      expect(cloned_context.references.count).to eq(source_context.references.count)
      expect(cloned_context.budgets.count).to eq(source_context.budgets.count)
      expect(cloned_context.subscriptions.count).to eq(source_context.subscriptions.count)
      expect(cloned_context.cash_transactions.count).to eq(source_context.cash_transactions.count)
      expect(cloned_context.card_transactions.count).to eq(source_context.card_transactions.count)
      expect(cloned_context.investments.count).to eq(source_context.investments.count)
      expect(cloned_context.cash_installments.count).to eq(source_context.cash_installments.count)
      expect(cloned_context.card_installments.count).to eq(source_context.card_installments.count)

      cloned_reference = cloned_context.references.find_by!(user_card:, month: 3, year: 2026)
      expect(cloned_reference.reference_date).to eq(Date.new(2026, 3, 12))

      cloned_budget = cloned_context.budgets.find_by!(description: budget.description, month: budget.month, year: budget.year)
      expect(cloned_budget.category_ids).to eq([ category.id ])
      expect(cloned_budget.entity_ids).to eq([ entity.id ])
      expect(cloned_budget.remaining_value).to eq(budget.remaining_value)

      cloned_subscription = cloned_context.subscriptions.find_by!(description: "Gym")
      expect(cloned_subscription.category_ids).to eq([ category.id ])
      expect(cloned_subscription.entity_ids).to eq([ entity.id ])

      cloned_cash_transaction = cloned_context.cash_transactions.find_by!(description: cash_transaction.description, subscription_id: cloned_subscription.id)
      expect(cloned_cash_transaction.user_bank_account_id).to eq(user_bank_account.id)
      expect(cloned_cash_transaction.category_ids).to match_array(cash_transaction.reload.category_ids)
      expect(cloned_cash_transaction.entity_ids).to match_array(cash_transaction.entity_ids)
      expect(cloned_cash_transaction.reference_transactable_id).to be_nil
      expect(cloned_cash_transaction.cash_installments.order(:number).pluck(:number, :price)).to eq(
        cash_transaction.cash_installments.order(:number).pluck(:number, :price)
      )

      cloned_card_transaction = cloned_context.card_transactions.find_by!(description: card_transaction.description, subscription_id: cloned_subscription.id)
      expect(cloned_card_transaction.user_card_id).to eq(user_card.id)
      expect(cloned_card_transaction.category_ids).to match_array(card_transaction.reload.category_ids)
      expect(cloned_card_transaction.entity_ids).to match_array(card_transaction.entity_ids)
      expect(cloned_card_transaction.card_installments.order(:number).pluck(:number, :price)).to eq(
        card_transaction.card_installments.order(:number).pluck(:number, :price)
      )
      expect(cloned_card_transaction.card_installments.pluck(:cash_transaction_id).compact).to all(be_in(cloned_context.cash_transactions.ids))

      cloned_investment = cloned_context.investments.find_by!(description: investment.description, date: investment.date)
      expect(cloned_investment.user_bank_account_id).to eq(user_bank_account.id)
      expect(cloned_investment.investment_type_id).to eq(investment_type.id)
      expect(cloned_investment.cash_transaction.context).to eq(cloned_context)
    end

    it "clones a linked graph with advances, subscriptions, references, and exchanges without leaking source ids" do
      user = create(:user)
      source_context = create(:context, user:, name: "Scenario")
      user_card = create(:user_card, user:)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      category = create(:category, :random, user:)
      entity = create(:entity, :random, user:)

      reference = create(
        :reference,
        context: source_context,
        user_card:,
        month: 4,
        year: 2026,
        reference_date: Date.new(2026, 4, 20),
        reference_closing_date: Date.new(2026, 4, 10)
      )

      subscription = create(:subscription, user:, context: source_context, description: "Big plan")
      subscription.categories = [ category ]
      subscription.entities = [ entity ]
      subscription.save!

      subscription_cash_transaction = create(
        :cash_transaction,
        user:,
        context: source_context,
        user_bank_account:,
        subscription:,
        description: "Subscription cash side"
      )
      subscription_cash_transaction.categories = [ category ]
      subscription_cash_transaction.entities = [ entity ]
      subscription_cash_transaction.save!

      subscription_card_transaction = create(
        :card_transaction,
        user:,
        context: source_context,
        user_card:,
        subscription:,
        description: "Subscription card side",
        date: Date.new(2026, 3, 18)
      )
      subscription_card_transaction.categories = [ category ]
      subscription_card_transaction.entities = [ entity ]
      subscription_card_transaction.save!

      advance_card_transaction = create(
        :card_transaction,
        user:,
        context: source_context,
        user_card:,
        description: "Advance origin",
        date: Date.new(2026, 3, 25),
        price: -20_000,
        category_transactions: [
          build(:category_transaction, category: user.built_in_category("CARD ADVANCE"), transactable: nil)
        ],
        entity_transactions: [
          build(
            :entity_transaction,
            entity: user.entities.find_or_create_by!(entity_name: user_card.user_card_name),
            transactable: nil,
            is_payer: false,
            price: 0,
            price_to_be_returned: 0
          )
        ]
      )
      advance_cash_transaction = CashTransaction.create!(advance_card_transaction.send(:advance_cash_transaction_params))
      advance_card_transaction.update_column(:advance_cash_transaction_id, advance_cash_transaction.id)

      exchange_return_cash_transaction = create(
        :cash_transaction,
        user:,
        context: source_context,
        user_bank_account:,
        description: "Loan repayment 1/3",
        cash_transaction_type: "Exchange",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026,
        price: -6_000
      )
      exchange_return_cash_transaction.categories = [ category ]
      exchange_return_cash_transaction.save!

      entity_transaction = subscription_card_transaction.entity_transactions.first
      entity_transaction.update!(
        price: -18_000,
        price_to_be_returned: -18_000,
        is_payer: true,
        exchanges_count: 3
      )
      create(
        :exchange,
        entity_transaction:,
        cash_transaction: exchange_return_cash_transaction,
        number: 1,
        month: 4,
        year: 2026,
        date: Date.new(2026, 4, 10),
        price: -6_000
      )

      subscription_card_transaction.update_columns(
        reference_transactable_type: "Reference",
        reference_transactable_id: reference.id
      )

      cloned_context = described_class.new(
        source_context:,
        name: "Scenario clone"
      ).call

      cloned_reference = cloned_context.references.find_by!(user_card:, month: 4, year: 2026)
      cloned_subscription = cloned_context.subscriptions.find_by!(description: "Big plan")
      cloned_subscription_cash_transaction = cloned_context.cash_transactions.find_by!(
        description: "Subscription cash side",
        subscription_id: cloned_subscription.id
      )
      cloned_subscription_card_transaction = cloned_context.card_transactions.find_by!(
        description: "Subscription card side",
        subscription_id: cloned_subscription.id
      )
      cloned_advance_card_transaction = cloned_context.card_transactions.find_by!(description: "Advance origin")
      cloned_exchange_return_cash_transaction = cloned_context.cash_transactions.find_by!(
        description: "Loan repayment 1/3",
        cash_transaction_type: "Exchange"
      )

      expect(cloned_subscription_cash_transaction.context).to eq(cloned_context)
      expect(cloned_subscription_card_transaction.context).to eq(cloned_context)
      expect(cloned_subscription_cash_transaction.subscription).to eq(cloned_subscription)
      expect(cloned_subscription_card_transaction.subscription).to eq(cloned_subscription)

      expect(cloned_advance_card_transaction.advance_cash_transaction).to be_present
      expect(cloned_advance_card_transaction.advance_cash_transaction.context).to eq(cloned_context)
      expect(cloned_advance_card_transaction.advance_cash_transaction_id).not_to eq(advance_card_transaction.advance_cash_transaction_id)

      cloned_exchange = cloned_subscription_card_transaction.entity_transactions.first.exchanges.first
      expect(cloned_exchange).to be_present
      expect(cloned_exchange.cash_transaction).to eq(cloned_exchange_return_cash_transaction)
      expect(cloned_exchange.entity_transaction.transactable).to eq(cloned_subscription_card_transaction)
      expect(cloned_exchange.id).not_to eq(entity_transaction.reload.exchanges.first.id)

      expect(cloned_reference.id).not_to eq(reference.id)
      expect(cloned_subscription_card_transaction.reference_transactable_id).to be_nil
      expect(cloned_subscription_card_transaction.reference_transactable_type).to be_nil
      expect(cloned_subscription_cash_transaction.reference_transactable_id).to be_nil
      expect(cloned_subscription_cash_transaction.reference_transactable_type).to be_nil
    end

    it "rolls back the whole clone when a later clone step fails" do
      user = create(:user)
      source_context = create(:context, user:, name: "Rollback Source")
      user_card = create(:user_card, user:)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      category = create(:category, :random, user:)
      entity = create(:entity, :random, user:)

      create(
        :reference,
        context: source_context,
        user_card:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 12),
        reference_closing_date: Date.new(2026, 3, 7)
      )

      budget = create(:budget, user:, context: source_context, month: 3, year: 2026, value: -10_000, remaining_value: -7_500)
      budget.categories = [ category ]
      budget.entities = [ entity ]
      budget.save!

      subscription = create(:subscription, user:, context: source_context, description: "Rollback Subscription")
      subscription.categories = [ category ]
      subscription.entities = [ entity ]
      subscription.save!

      cash_transaction = create(
        :cash_transaction,
        user:,
        context: source_context,
        user_bank_account:,
        subscription:,
        description: "Rollback cash side"
      )
      cash_transaction.categories = [ category ]
      cash_transaction.entities = [ entity ]
      cash_transaction.save!

      card_transaction = create(
        :card_transaction,
        user:,
        context: source_context,
        user_card:,
        subscription:,
        description: "Rollback card side"
      )
      card_transaction.categories = [ category ]
      card_transaction.entities = [ entity ]
      card_transaction.save!

      service = described_class.new(source_context:, name: "Broken clone")

      counts_before = {
        contexts: user.contexts.count,
        references: Reference.count,
        budgets: Budget.count,
        subscriptions: Subscription.count,
        cash_transactions: CashTransaction.count,
        card_transactions: CardTransaction.count,
        cash_installments: CashInstallment.count,
        card_installments: CardInstallment.count,
        category_transactions: CategoryTransaction.count,
        entity_transactions: EntityTransaction.count
      }

      allow(service).to receive(:insert_clone!).and_wrap_original do |original, model, record, overrides: {}|
        raise "forced card transaction clone failure" if model == CardTransaction

        original.call(model, record, overrides:)
      end

      expect { service.call }.to raise_error(RuntimeError, "forced card transaction clone failure")

      expect(user.contexts.find_by(name: "Broken clone")).to be_nil
      expect(user.contexts.count).to eq(counts_before[:contexts])
      expect(Reference.count).to eq(counts_before[:references])
      expect(Budget.count).to eq(counts_before[:budgets])
      expect(Subscription.count).to eq(counts_before[:subscriptions])
      expect(CashTransaction.count).to eq(counts_before[:cash_transactions])
      expect(CardTransaction.count).to eq(counts_before[:card_transactions])
      expect(CashInstallment.count).to eq(counts_before[:cash_installments])
      expect(CardInstallment.count).to eq(counts_before[:card_installments])
      expect(CategoryTransaction.count).to eq(counts_before[:category_transactions])
      expect(EntityTransaction.count).to eq(counts_before[:entity_transactions])
    end
  end
end
