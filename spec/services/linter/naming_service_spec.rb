# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linter::NamingService do
  it "preserves an explicitly empty scope instead of falling back to every user transaction" do
    user = create(:user, :random)

    expect(described_class.new(cash_transactions: [], user:, dry_run: true).call).to be_empty
  end

  it "preserves the legacy user-wide fallback when no scope is provided" do
    user = create(:user, :random)
    investment = create(
      :investment,
      :random,
      user:,
      context: user.main_context,
      user_bank_account: create(:user_bank_account, :random, user:),
      investment_type: create(:investment_type, :random)
    )
    investment.cash_transaction.update_columns(description: "OUTDATED NAMING")

    results = described_class.new(user:, dry_run: true).call

    expect(results).to include(
      hash_including(
        convention: :investment,
        record: hash_including(id: investment.cash_transaction_id),
        changes: hash_including(:description)
      )
    )
  end
end
