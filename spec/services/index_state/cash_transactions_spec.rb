# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndexState::CashTransactions do
  include ActiveSupport::Testing::TimeHelpers

  describe "#to_h" do
    it "does not activate a previous month when its only unpaid row is a zeroed failed return" do
      travel_to Time.zone.local(2026, 6, 10, 12) do
        user = create(:user, :random)
        bank = create(:bank, :random)
        user_bank_account = create(:user_bank_account, :random, user:, bank:)
        failed_category = user.built_in_category("FAILED LEND/BORROW RETURN")

        failed_return = create(
          :cash_transaction,
          user:,
          context: user.main_context,
          user_bank_account:,
          description: "Failed lend return",
          date: Time.zone.local(2026, 5, 20, 12),
          month: 5,
          year: 2026,
          price: 0,
          cash_installments: [
            build(:cash_installment, number: 1, date: Time.zone.local(2026, 5, 20, 12), month: 5, year: 2026, price: 0, starting_price: -1_000, paid: false)
          ]
        )
        failed_return.categories = [ failed_category ]
        failed_return.save!

        state = described_class.new(
          current_user: user,
          current_context: user.main_context,
          params: ActionController::Parameters.new,
          cash_installments: user.main_context.cash_installments
        ).to_h

        expect(state[:active_month_years]).to eq([ 202_606 ])
      end
    end
  end
end
