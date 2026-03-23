# frozen_string_literal: true

require "rails_helper"

RSpec.shared_examples "main-context-scoped import aftermath" do |service_class|
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card: create(:card, :random, bank:), due_date_day: 12, days_until_due_date: 5) }
  let(:service) do
    service_class.allocate.tap do |instance|
      instance.instance_variable_set(:@user, user)
    end
  end

  it "creates missing references only in the main context" do
    main_invoice = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account:,
      user_card:,
      description: "Main invoice",
      cash_transaction_type: "CardInstallment",
      date: Date.new(2026, 3, 12),
      month: 3,
      year: 2026,
      price: -1000,
      paid: false
    )
    main_invoice.categories = [ user.built_in_category("CARD PAYMENT") ]
    main_invoice.save!
    main_card_transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card:,
      date: Date.new(2026, 2, 10),
      month: 3,
      year: 2026,
      price: -1000,
      paid: false
    )
    main_card_transaction.card_installments.first.update!(cash_transaction: main_invoice, month: 3, year: 2026)

    derived_context = create(:context, user:, name: "#{service_class.name} derived", source_context: user.main_context)
    derived_invoice = create(
      :cash_transaction,
      user:,
      context: derived_context,
      user_bank_account:,
      user_card:,
      description: "Derived invoice",
      cash_transaction_type: "CardInstallment",
      date: Date.new(2026, 3, 13),
      month: 3,
      year: 2026,
      price: -1000,
      paid: false
    )
    derived_invoice.categories = [ user.built_in_category("CARD PAYMENT") ]
    derived_invoice.save!
    derived_card_transaction = create(
      :card_transaction,
      user:,
      context: derived_context,
      user_card:,
      date: Date.new(2026, 2, 11),
      month: 3,
      year: 2026,
      price: -1000,
      paid: false
    )
    derived_card_transaction.card_installments.first.update!(cash_transaction: derived_invoice, month: 3, year: 2026)

    service.send(:fix_missing_references)

    expect(user_card.references.find_by(context: user.main_context, month: 3, year: 2026)).to be_present
    expect(user_card.references.find_by(context: derived_context, month: 3, year: 2026)).to be_nil
  end

  it "corrects investment dates only in the main context" do
    main_investment_transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account:,
      cash_transaction_type: "Investment",
      date: Date.new(2026, 3, 18),
      month: 3,
      year: 2026,
      price: 1000
    )
    derived_context = create(:context, user:, name: "#{service_class.name} investments", source_context: user.main_context)
    derived_investment_transaction = create(
      :cash_transaction,
      user:,
      context: derived_context,
      user_bank_account:,
      cash_transaction_type: "Investment",
      date: Date.new(2026, 3, 19),
      month: 3,
      year: 2026,
      price: 1000
    )

    service.send(:correct_investment_dates)

    expect(main_investment_transaction.reload.date.to_date).to eq(Date.new(2026, 3, 1))
    expect(derived_investment_transaction.reload.date.to_date).to eq(Date.new(2026, 3, 19))
  end

  it "passes only the main context into balance recalculation" do
    recalculation = instance_double(Logic::RecalculateBalancesService, call: true)

    expect(Logic::RecalculateBalancesService).to receive(:new)
      .with(user:, context: user.main_context, year: 2021, month: 1)
      .and_return(recalculation)

    service.send(:recalculate_balance)
  end
end

RSpec.describe Import::FromGigiExcel do
  include_examples "main-context-scoped import aftermath", described_class
end

RSpec.describe Import::FromRikkiExcel do
  include_examples "main-context-scoped import aftermath", described_class
end
