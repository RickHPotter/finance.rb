# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::OperationQuery do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }

  def create_operation(owner:, source: :web, item_id: 1, event: :update)
    operation = AuditOperation.create!(source:, result: :committed, actor_id: owner.id)
    AuditVersion.create!(
      operation:,
      owner_id: owner.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id:,
      event:,
      mutation_source: source,
      object_changes: { "description" => %w[Before After] },
      metadata: {}
    )
    operation
  end

  it "returns only operations containing a version owned by the ordinary reader" do
    own_operation = create_operation(owner: user, item_id: 10)
    create_operation(owner: other_user, item_id: 20)

    expect(described_class.new(reader: user).call.records).to eq([ own_operation ])
  end

  it "keeps a mixed-owner operation visible without broadening its version scope" do
    operation = create_operation(owner: user, item_id: 10)
    AuditVersion.create!(
      operation:,
      owner_id: other_user.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: 20,
      event: :create,
      mutation_source: :web,
      object_changes: { "description" => [ nil, "Foreign" ] },
      metadata: {}
    )

    expect(described_class.new(reader: user).find(operation.id)).to eq(operation)
    expect(Audit::VersionQuery.authorized_scope(user).where(operation:).count).to eq(1)
  end

  it "allows administrators to filter global operations through version metadata" do
    expected = create_operation(owner: user, source: :admin_repair, item_id: 44, event: :destroy)
    create_operation(owner: other_user, source: :import, item_id: 55)

    result = described_class.new(
      reader: admin,
      filters: { source: "admin_repair", owner_id: user.id, item_type: "CashTransaction", item_id: 44, event: "destroy" }
    ).call

    expect(result.records).to eq([ expected ])
  end
end
