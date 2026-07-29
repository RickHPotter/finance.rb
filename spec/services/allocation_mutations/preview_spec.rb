# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::Preview do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:source) { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }

  def transaction(description)
    create(
      :cash_transaction,
      user:,
      context:,
      description:,
      user_bank_account: create(:user_bank_account, :random, user:),
      category_transactions: []
    )
  end

  def action(allocation_type: :category, operation: :add, source_id: nil, destination_id: destination.id)
    AllocationMutations::Action.new(allocation_type:, operation:, source_id:, destination_id:)
  end

  def preview(owners:, mutation_action: action, selected_row_count: owners.size)
    AllocationMutations::BatchPlanner.new(
      actor: user,
      context:,
      owner_type: owners.first.class.base_class.name,
      owner_ids: owners.map(&:id),
      selected_row_count:,
      action: mutation_action
    ).call
  end

  it "reports selected rows separately from unique owners and remains completely read-only" do
    eligible = transaction("Eligible")
    noop = transaction("No-op")
    noop.category_transactions.create!(category: destination)
    timestamps = [ eligible.updated_at, noop.updated_at ]
    operation_count = AuditOperation.count

    result = nil
    expect do
      result = preview(owners: [ eligible, noop ], selected_row_count: 3)
    end.not_to change(CategoryTransaction, :count)

    expect(AuditOperation.count).to eq(operation_count)
    expect([ eligible.reload.updated_at, noop.reload.updated_at ]).to eq(timestamps)
    expect(result).to have_attributes(
      selected_row_count: 3,
      unique_owner_count: 2,
      eligible_count: 1,
      affected_count: 1,
      noop_count: 1,
      conflict_count: 0
    )
    expect(result).to be_strict_apply_available
    expect(result).not_to be_eligible_only_available
  end

  it "groups localized reasons with bounded representative owner links" do
    owners = Array.new(6) { |index| transaction("Already present #{index}") }
    owners.each { |owner| owner.category_transactions.create!(category: destination) }

    result = I18n.with_locale(:"pt-BR") { preview(owners:) }
    group = result.reason_groups.sole

    expect(group).to include(status: :noop, reason_code: :destination_present, count: 6)
    expect(group[:label]).to be_present
    expect(group[:owners].size).to eq(5)
    expect(group[:owners].first[:path]).to eq(Rails.application.routes.url_helpers.cash_transaction_path(owners.first))
  end

  it "signs actor, context, action, selection, and deterministic result digest into an expiring token" do
    owner = transaction("Signed")
    first = preview(owners: [ owner ], selected_row_count: 2)
    second = preview(owners: [ owner ], selected_row_count: 2)
    payload = AllocationMutations::PreviewToken.verify(first.apply_token)

    expect(first.digest).to eq(second.digest)
    expect(payload).to include(
      "actor_id" => user.id,
      "context_id" => context.id,
      "digest" => first.digest
    )
    expect(payload.fetch("selection")).to include(
      "owner_type" => "CashTransaction",
      "owner_ids" => [ owner.id ],
      "selected_row_count" => 2
    )
    expect(payload.fetch("action")).to include(
      "allocation_type" => "category",
      "operation" => "add",
      "destination_id" => destination.id
    )

    travel 16.minutes do
      expect(AllocationMutations::PreviewToken.verify(first.apply_token)).to be_nil
    end
  end

  it "offers eligible-only application for independent payer conflicts" do
    entity = create(:entity, user:, entity_name: "ENTITY")
    ordinary = transaction("Ordinary")
    payer = transaction("Payer")
    ordinary.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    payer.entity_transactions.create!(entity:, is_payer: true, price: 100, price_to_be_returned: 100)
    remove = action(allocation_type: :entity, operation: :remove, source_id: entity.id, destination_id: nil)

    result = preview(owners: [ ordinary, payer ], mutation_action: remove)

    expect(result).to have_attributes(eligible_count: 1, conflict_count: 1)
    expect(result).not_to be_strict_apply_available
    expect(result).to be_eligible_only_available
  end

  it "disables eligible-only application when a structural owner conflicts" do
    entity = create(:entity, user:, entity_name: "ENTITY")
    ordinary = transaction("Ordinary")
    structural = transaction("Piggy Bank")
    ordinary.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    structural.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    structural.category_transactions.create!(category: user.built_in_category("PIGGY BANK"))
    remove = action(allocation_type: :entity, operation: :remove, source_id: entity.id, destination_id: nil)

    result = preview(owners: [ ordinary, structural ], mutation_action: remove)

    expect(result).to have_attributes(eligible_count: 1, conflict_count: 1)
    expect(result).not_to be_eligible_only_available
  end
end
