# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::VersionQuery do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:operation) { AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, request_id: "request-own") }
  let(:other_operation) { AuditOperation.create!(source: :import, result: :committed, actor_id: other_user.id, request_id: "request-other") }

  def create_version(**attributes)
    owner = attributes.delete(:owner)
    defaults = {
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: 1,
      event: :update,
      mutation_source: :web,
      context_id: nil,
      object: { "description" => "Before" },
      object_changes: { "description" => %w[Before After] },
      metadata: {},
      created_at: Time.current
    }

    AuditVersion.create!(defaults.merge(attributes, owner_id: owner.id))
  end

  it "applies ownership before filters and ignores an ordinary reader's owner override" do
    own_version = create_version(operation:, owner: user, item_id: 10)
    create_version(operation: other_operation, owner: other_user, item_id: 20)

    result = described_class.new(reader: user, filters: { owner_id: other_user.id }).call

    expect(result.records).to eq([ own_version ])
  end

  it "allows administrators to filter the global scope by indexed metadata" do
    own_version = create_version(operation:, owner: user, item_id: 10, event: :destroy, context_id: 91)
    create_version(operation: other_operation, owner: other_user, item_id: 20)

    result = described_class.new(
      reader: admin,
      filters: {
        owner_id: user.id,
        context_id: 91,
        item_type: "CashTransaction",
        item_id: 10,
        event: "destroy",
        source: "web",
        actor_id: user.id,
        request_id: "request-own"
      }
    ).call

    expect(result.records).to eq([ own_version ])
  end

  it "normalizes installment subtypes and paginates deterministically with a hard limit" do
    timestamp = Time.zone.parse("2026-07-19 12:00:00")
    versions = 3.times.map do |index|
      create_version(
        operation:,
        owner: user,
        item_type: "Installment",
        item_subtype: "CashInstallment",
        item_id: index + 1,
        created_at: timestamp
      )
    end

    first_page = described_class.new(reader: user, filters: { item_type: "CashInstallment", page: 1, per_page: 2 }).call
    second_page = described_class.new(reader: user, filters: { item_type: "CashInstallment", page: 2, per_page: 2 }).call
    bounded_page = described_class.new(reader: user, filters: { per_page: 500 }).call

    expect(first_page.records.map(&:id)).to eq(versions.map(&:id).sort.reverse.first(2))
    expect(second_page.records.map(&:id)).to eq([ versions.map(&:id).min ])
    expect(first_page).to have_attributes(total_count: 3, total_pages: 2, next_page: 2)
    expect(bounded_page.per_page).to eq(100)
  end

  it "returns no rows for unsupported record types" do
    create_version(operation:, owner: user)

    expect(described_class.new(reader: user, filters: { item_type: "User" }).call.records).to be_empty
  end
end
