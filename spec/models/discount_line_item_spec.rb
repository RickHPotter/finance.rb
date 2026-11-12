# frozen_string_literal: true

require "rails_helper"

RSpec.describe LineItem, type: :model do
  let(:user) { create(:user, :random) }
  let(:transaction) { build(:cash_transaction, user:, context: user.main_context, price: -9000) }
  let(:discount_category) { user.built_in_category("DISCOUNT") }

  def discount_line(**attributes)
    transaction.line_items.build({ item_kind: "discount", description: "Discount", price: 1000, category_id: discount_category.id }.merge(attributes))
  end

  it "allows an expense discount with the user's reserved category" do
    expect(discount_line).to be_valid
  end

  it "rejects a discount with a different category or an entity" do
    line = discount_line(category_id: create(:category, :random, user:).id)
    line.entity_id = create(:entity, :random, user:).id

    expect(line).not_to be_valid
    expect(line.errors[:category_id]).to be_present
    expect(line.errors[:entity_id]).to be_present
  end

  it "rejects a second discount in the same transaction" do
    discount_line
    second = discount_line

    expect(second).not_to be_valid
    expect(second.errors[:item_kind]).to be_present
  end

  it "rejects a normal item using the reserved category" do
    line = transaction.line_items.build(description: "Item", price: -1000, category_id: discount_category.id)

    expect(line).not_to be_valid
    expect(line.errors[:category_id]).to be_present
  end
end
