# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::DirectApply do
  it "acquires the operation advisory lock with a quoted interpolated key" do
    actor = create(:user, :random)
    operation = AuditOperation.create!(
      source: :actionable_message,
      result: :committed,
      actor_id: actor.id,
      context_id: actor.main_context.id
    )
    service = described_class.new(operation:, actor:)

    expect do
      AuditOperation.transaction { service.send(:acquire_operation_lock!) }
    end.not_to raise_error
  end
end
