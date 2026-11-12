# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261028151000_add_discount_categories").to_s

RSpec.describe AddDiscountCategories do
  it "reuses an existing category and preserves its allocations and children" do
    user = create(:user, :random)
    category = user.categories.find_by!(category_name: "DISCOUNT", parent_category_id: nil)
    category.update!(built_in: false, colour: "#123456")
    child = create(:category, :random, user:, parent_category: category)
    transaction = create(:cash_transaction, user:, context: user.main_context)
    transaction.categories << category

    2.times { described_class.new.up }

    expect(category.reload).to be_built_in
    expect(category.colour).to eq("#123456")
    expect(transaction.reload.category_ids).to include(category.id)
    expect(child.reload).to be_valid
    expect(user.categories.where(category_name: "DISCOUNT", parent_category_id: nil).count).to eq(1)
  end
end
