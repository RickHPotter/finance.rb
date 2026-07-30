# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::Outcome do
  let(:owner) { CashTransaction.new(id: 41) }

  it "builds typed eligible, no-op, and conflict outcomes" do
    eligible = described_class.eligible(owner:)
    noop = described_class.noop(owner:, reason_code: :already_present)
    conflict = described_class.conflict(owner:, reason_code: :payer_entity, details: { allocation_id: 9 })

    expect(eligible).to be_eligible
    expect(noop).to be_noop
    expect(conflict).to be_conflict
    expect(conflict).to have_attributes(
      owner_type: "CashTransaction",
      owner_id: owner.id,
      reason_code: :payer_entity,
      details: { allocation_id: 9 }
    )
  end

  it "rejects invalid outcome state" do
    expect do
      described_class.new(status: :ignored, owner_type: "CashTransaction", owner_id: 1, reason_code: :unknown, details: {})
    end.to raise_error(ArgumentError, /unsupported allocation outcome/)
  end
end
