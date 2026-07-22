# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::VersionMetadata do
  it "keeps only scalar routing identifiers allowlisted for the model" do
    transaction = CashTransaction.new(
      id: 12,
      user_bank_account_id: 31,
      subscription_id: 47,
      reference_transactable_type: "CardTransaction",
      reference_transactable_id: 59,
      description: "Must stay in the version payload"
    )

    expect(described_class.for(transaction)).to eq(
      "user_bank_account_id" => 31,
      "subscription_id" => 47,
      "reference_transactable_type" => "CardTransaction",
      "reference_transactable_id" => 59
    )
  end

  it "fails closed when a model has no metadata allowlist" do
    expect { described_class.for(User.new) }.to raise_error(KeyError)
  end
end
