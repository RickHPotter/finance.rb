# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::RecalculateCountAndTotalService do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }

  def allocation_attributes
    {
      category_transactions: [ build(:category_transaction, category:, transactable: nil) ],
      entity_transactions: [
        build(
          :entity_transaction,
          entity:,
          transactable: nil,
          is_payer: false,
          price: 0,
          price_to_be_returned: 0
        )
      ]
    }
  end

  it "recalculates cash allocation totals when the through associations were loaded before creation" do
    account = create(:user_bank_account, :random, user:, bank: create(:bank, :random))
    transaction = build(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      price: -2_300,
      date: Date.new(2027, 3, 25),
      **allocation_attributes
    )
    transaction.categories.load
    transaction.entities.load

    transaction.save!

    expect(category.reload).to have_attributes(cash_transactions_count: 1, cash_transactions_total: -2_300)
    expect(entity.reload).to have_attributes(cash_transactions_count: 1, cash_transactions_total: -2_300)
  end

  it "recalculates card allocation totals when the through associations were loaded before creation" do
    user_card = create(:user_card, :random, user:)
    transaction = build(
      :card_transaction,
      user:,
      context:,
      user_card:,
      price: -2_300,
      date: Date.new(2027, 3, 25),
      **allocation_attributes
    )
    transaction.categories.load
    transaction.entities.load

    transaction.save!

    expect(category.reload).to have_attributes(card_transactions_count: 1, card_transactions_total: -2_300)
    expect(entity.reload).to have_attributes(card_transactions_count: 1, card_transactions_total: -2_300)
  end
end
