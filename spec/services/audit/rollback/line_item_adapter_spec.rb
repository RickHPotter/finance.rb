# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit rollback LineItem adapter" do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:transaction) do
    PaperTrail.request(enabled: false) do
      create(
        :cash_transaction,
        user:,
        context:,
        user_bank_account: account,
        category_transactions: [],
        entity_transactions: [],
        price: 100_00
      )
    end
  end
  let(:operation) { AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, context_id: context.id) }

  def version_attributes(record)
    {
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: record.class.name,
      item_subtype: record.class.name,
      item_id: record.id,
      mutation_source: :web,
      metadata: Audit::VersionMetadata.for(record)
    }
  end

  def record_create(record)
    state = record.attributes.except(*record.class.paper_trail_options.fetch(:skip))
    AuditVersion.create!(
      **version_attributes(record),
      event: :create,
      object: nil,
      object_changes: state.transform_values { |value| [ nil, value ] }
    )
  end

  def record_update(record, before:, changes:)
    AuditVersion.create!(**version_attributes(record), event: :update, object: before, object_changes: changes)
  end

  def record_destroy(record, state:)
    AuditVersion.create!(
      **version_attributes(record),
      event: :destroy,
      object: state,
      object_changes: state.transform_values { |value| [ value, nil ] }
    )
  end

  def apply
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token
    ).call
    [ preview, result ]
  end

  it "destroys a newly created line item and identifies its parent transaction dependency" do
    line_item = PaperTrail.request(enabled: false) do
      create(:line_item, transactable: transaction, price: 50_00, category:)
    end
    record_create(line_item)

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(preview.rows.sole.dependencies).to contain_exactly(
      have_attributes(record_type: "CashTransaction", item_id: transaction.id, relationship: "parent", included: false)
    )
    expect(result).to have_attributes(status: "applied")
    expect(LineItem).not_to exist(line_item.id)
  end

  it "restores an updated line item to its previous state" do
    line_item = PaperTrail.request(enabled: false) do
      create(:line_item, transactable: transaction, description: "Apples", price: 50_00, category:)
    end
    before = line_item.attributes.except(*LineItem.paper_trail_options.fetch(:skip)).merge(
      "description" => "Apples",
      "price" => 50_00
    )
    line_item.update_columns(description: "Oranges", price: 60_00)
    record_update(
      line_item,
      before:,
      changes: {
        "description" => %w[Apples Oranges],
        "price" => [ 50_00, 60_00 ]
      }
    )

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(line_item.reload).to have_attributes(description: "Apples", price: 50_00)
  end

  it "recreates a destroyed line item from its audit version" do
    line_item = PaperTrail.request(enabled: false) do
      create(:line_item, transactable: transaction, description: "Apples", price: 50_00, category:)
    end
    state = line_item.attributes.except(*LineItem.paper_trail_options.fetch(:skip))
    line_item.destroy!
    record_destroy(line_item, state:)

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    recreated = LineItem.find_by(id: line_item.id)
    expect(recreated).to be_present
    expect(recreated).to have_attributes(description: "Apples", price: 50_00)
  end

  it "restores a deleted discount together with its fixed category" do
    discount_category = user.categories.find_by!(category_name: "DISCOUNT", parent_category_id: nil)
    expense = PaperTrail.request(enabled: false) do
      create(:cash_transaction, user:, context:, user_bank_account: account, price: -9000,
                                cash_installments: [ build(:cash_installment, number: 1, price: -9000) ],
                                line_items: [
                                  LineItem.new(description: "Product", price: -10_000),
                                  LineItem.new(description: "Discount", price: 1000, item_kind: "discount",
                                               category_transactions: [ CategoryTransaction.new(category: discount_category) ])
                                ])
    end
    discount = expense.line_items.find(&:discount?)
    allocation = discount.category_transactions.sole
    discount_state = discount.attributes.except(*LineItem.paper_trail_options.fetch(:skip))
    allocation_state = allocation.attributes.except(*CategoryTransaction.paper_trail_options.fetch(:skip))
    PaperTrail.request(enabled: false) { discount.destroy! }
    record_destroy(discount, state: discount_state)
    record_destroy(allocation, state: allocation_state)

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(LineItem.find(discount.id)).to have_attributes(item_kind: "discount", price: 1000, category_id: discount_category.id)
  end
end
