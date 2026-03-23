# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::RecalculateBalancesService do
  describe "#call" do
    it "recalculates only the selected context balances" do
      user = create(:user, :random)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, :random, user:, bank:)

      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main salary",
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: 1000)
        ]
      )
      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main expense",
        date: Date.new(2026, 3, 11),
        month: 3,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 3, 11), month: 3, year: 2026, price: -400)
        ]
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Recalc Isolation"
      ).call

      main_state_before = user.main_context.cash_installments.order(:id).pluck(:id, :balance, :order_id)
      derived_installment = derived_context.cash_installments.order(:id).first
      derived_installment.update_columns(price: 2_500)

      described_class.new(user:, context: derived_context, year: 2026, month: 3).call

      expect(derived_context.cash_installments.order(:id).pluck(:id, :balance, :order_id)).not_to eq(main_state_before)
      expect(user.main_context.cash_installments.order(:id).pluck(:id, :balance, :order_id)).to eq(main_state_before)
    end
  end
end
