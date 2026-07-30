# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::FormCoordinator do
  def error_codes(owner)
    described_class.new(
      owner:,
      entity_attributes: owner.submitted_entity_transaction_attributes
    ).call.errors.map(&:code)
  end

  it "accepts a payer replacement represented as removal plus a configured new row" do
    transaction = create(:cash_transaction)
    old_entity = create(:entity, user: transaction.user, entity_name: "OLD PAYER")
    new_entity = create(:entity, user: transaction.user, entity_name: "NEW PAYER")
    old_allocation = transaction.entity_transactions.create!(
      entity: old_entity,
      price: transaction.price,
      price_to_be_returned: transaction.price,
      is_payer: true
    )

    transaction.cash_installments.first.update_column(:paid, true)
    transaction.reload
    transaction.entity_transactions_attributes = [
      { id: old_allocation.id, entity_id: old_entity.id, _destroy: true },
      { entity_id: new_entity.id, price: transaction.price, price_to_be_returned: transaction.price, is_payer: true }
    ]

    expect(error_codes(transaction)).to be_empty
    expect(transaction.save).to be(true)
    expect(transaction.reload.entity_transactions.sole).to have_attributes(entity_id: new_entity.id, is_payer: true)
  end

  it "accepts the same payer replacement contract for a paid card transaction" do
    transaction = create(:card_transaction)
    old_allocation = transaction.entity_transactions.first
    old_allocation.update!(price: transaction.price, price_to_be_returned: transaction.price, is_payer: true)
    new_entity = create(:entity, user: transaction.user, entity_name: "NEW CARD PAYER")

    transaction.card_installments.first.update_column(:paid, true)
    transaction.reload
    transaction.entity_transactions_attributes = [
      { id: old_allocation.id, entity_id: old_allocation.entity_id, _destroy: true },
      { entity_id: new_entity.id, price: transaction.price, price_to_be_returned: transaction.price, is_payer: true }
    ]

    expect(error_codes(transaction)).to be_empty
    expect(transaction.save).to be(true)
    expect(transaction.reload.entity_transactions.sole).to have_attributes(entity_id: new_entity.id, is_payer: true)
  end

  it "protects an exchange-bearing friend identity from an in-place replacement" do
    transaction = create(:card_transaction)
    allocation = transaction.entity_transactions.first
    friend = create(:user, :random)
    other_friend = create(:user, :random)
    allocation.update!(entity: create(:entity, user: transaction.user, entity_name: "FRIEND", entity_user: friend))
    create(:exchange, entity_transaction: allocation, exchange_type: :non_monetary, price: 0)
    replacement = create(:entity, user: transaction.user, entity_name: "OTHER FRIEND", entity_user: other_friend)

    transaction.entity_transactions_attributes = [
      allocation.slice(:id, :price, :price_to_be_returned).merge(entity_id: replacement.id)
    ]

    expect(error_codes(transaction)).to include(:entity_replacement_requires_destroy_and_add)
    expect(transaction).to be_invalid
  end

  it "rejects categories and entities owned by another user" do
    transaction = create(:cash_transaction)
    other_user = create(:user, :random)

    transaction.category_transactions.build(category: create(:category, user: other_user, category_name: "FOREIGN"))
    transaction.entity_transactions.build(entity: create(:entity, user: other_user, entity_name: "FOREIGN"), price: 0, price_to_be_returned: 0)

    expect(error_codes(transaction)).to include(:allocation_category_not_owned, :allocation_entity_not_owned)
    expect(transaction).to be_invalid
  end

  it "protects a persisted generated transaction category based on the final state" do
    transaction = create(:cash_transaction)
    investment_category = transaction.user.built_in_category("INVESTMENT")
    allocation = transaction.category_transactions.create!(category: investment_category)
    transaction.update_column(:cash_transaction_type, "Investment")
    transaction.reload

    transaction.category_transactions_attributes = [
      { id: allocation.id, category_id: investment_category.id, _destroy: true }
    ]

    expect(error_codes(transaction)).to include(:generated_allocation_category_required)
    expect(transaction).to be_invalid
  end

  it "delegates a Piggy Bank source entity replacement to projection synchronization" do
    user = create(:user)
    original_entity = create(:entity, user:, entity_name: "ORIGINAL BANK")
    replacement_entity = create(:entity, user:, entity_name: "REPLACEMENT BANK")
    source = build(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: create(:user_bank_account, :random, user:),
      description: "Coordinated reserve",
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, paid: false) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity: original_entity, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
    )
    source.save!
    original_allocation = source.entity_transactions.find_by!(entity: original_entity)

    source.entity_transactions_attributes = [
      { id: original_allocation.id, entity_id: original_entity.id, _destroy: true },
      { entity_id: replacement_entity.id, price: 0, price_to_be_returned: 0, is_payer: false }
    ]
    source.save!

    expect(source.reload.entities).to contain_exactly(replacement_entity)
    expect(source.piggy_bank.return_cash_transaction.reload.entities).to contain_exactly(replacement_entity)
  end

  it "requires subscription-owned allocations to be changed by the subscription workflow" do
    subscription = create(:subscription)
    entity = create(:entity, user: subscription.user, entity_name: "SUBSCRIPTION ENTITY")
    subscription.entities << entity
    transaction = create(
      :cash_transaction,
      user: subscription.user,
      context: subscription.context,
      user_bank_account: create(:user_bank_account, :random, user: subscription.user)
    )
    subscription.attach_transactions!([ transaction ])
    transaction.reload
    allocation = transaction.entity_transactions.find_by!(entity:)

    transaction.entity_transactions_attributes = [
      { id: allocation.id, entity_id: entity.id, _destroy: true }
    ]

    expect(error_codes(transaction)).to include(:subscription_allocation_managed)
    expect(transaction).to be_invalid
  end
end
