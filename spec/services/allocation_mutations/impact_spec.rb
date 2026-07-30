# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::Impact do
  it "captures normalized before/after allocation and reference impact" do
    user = User.new(id: 1)
    context = Context.new(id: 2, user:)
    transaction = CashTransaction.new(id: 3, user:, context:, date: Date.new(2026, 7, 1), month: 7, year: 2026, price: 100)

    impact = described_class.build(
      owner: transaction,
      category_ids_before: [ 8, 3, 8 ],
      category_ids_after: [ 5, 8 ],
      entity_ids_before: [ 4 ],
      entity_ids_after: [ 4 ],
      balance_recalculation_required: false
    )

    expect(impact).to have_attributes(
      owner_type: "CashTransaction",
      owner_id: transaction.id,
      context_id: transaction.context_id,
      category_ids_before: [ 3, 8 ],
      category_ids_after: [ 5, 8 ],
      entity_ids_before: [ 4 ],
      entity_ids_after: [ 4 ]
    )
    expect(impact.affected_category_ids).to eq([ 3, 5, 8 ])
    expect(impact).to be_category_changed
    expect(impact).not_to be_entity_changed
  end
end
