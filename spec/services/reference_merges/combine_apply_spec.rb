# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferenceMerges::CombineApply do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:) }

  subject(:service) do
    described_class.new(
      user_card:,
      context:,
      source_date: Date.new(2026, 8, 1),
      target_date: Date.new(2026, 9, 1)
    )
  end

  it "rejects a missing canonical graph without audit history" do
    service
    result = nil

    expect { result = service.call }.not_to change(AuditOperation, :count)

    expect(result).to have_attributes(status: "rejected", reason_code: "combine_missing_root", operation: nil)
  end

  it "rejects a context owned by another user before mutation" do
    foreign_context = create(:user, :different).main_context
    result = described_class.new(
      user_card:,
      context: foreign_context,
      source_date: Date.new(2026, 8, 1),
      target_date: Date.new(2026, 9, 1)
    ).call

    expect(result).to have_attributes(status: "rejected", reason_code: "context_mismatch", operation: nil)
  end

  it "acquires the shared user-card/context advisory lock with a safely quoted key" do
    expect do
      ApplicationRecord.transaction { ReferenceMerges::Lock.acquire!(user_card:, context:) }
    end.not_to raise_error
  end
end
