# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::NetState do
  let(:operation) { AuditOperation.create!(source: :web, result: :committed) }

  def create_version(item_id:, event:, object:, changes:)
    AuditVersion.create!(
      operation:,
      owner_id: 11,
      context_id: 22,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id:,
      event:,
      mutation_source: :web,
      object:,
      object_changes: changes,
      metadata: {}
    )
  end

  it "collapses repeated updates into one deterministic net transition" do
    create_version(item_id: 7, event: :update, object: { "id" => 7, "description" => "First" }, changes: { "description" => %w[First Second] })
    create_version(item_id: 7, event: :update, object: { "id" => 7, "description" => "Second" }, changes: { "description" => %w[Second Third] })

    transition = described_class.new(versions: operation.audit_versions).call.sole

    expect(transition).to have_attributes(
      key: "CashTransaction:7",
      action: "update",
      event_sequence: %w[update update]
    )
    expect(transition.before_state.fetch("description")).to eq("First")
    expect(transition.expected_after_state.fetch("description")).to eq("Third")
  end

  it "represents create followed by destroy as a visible no-op" do
    create_version(item_id: 8, event: :create, object: nil, changes: { "id" => [ nil, 8 ], "description" => [ nil, "Temporary" ] })
    create_version(item_id: 8, event: :destroy, object: { "id" => 8, "description" => "Temporary" }, changes: {})

    transition = described_class.new(versions: operation.audit_versions).call.sole

    expect(transition).to have_attributes(action: "none", before_state: nil, expected_after_state: nil, event_sequence: %w[create destroy])
  end
end
