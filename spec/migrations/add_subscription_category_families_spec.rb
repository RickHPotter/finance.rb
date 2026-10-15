# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261015120000_add_subscription_category_families").to_s

RSpec.describe AddSubscriptionCategoryFamilies do
  it "preserves existing salary category IDs and allocations while making them built-in" do
    user = create(:user, :random)
    salary = user.categories.find_by!(category_name: "SALARY")
    salary.update!(built_in: false)
    transaction = create(:cash_transaction, user:, context: user.main_context)
    transaction.categories << salary

    described_class.new.up

    expect(salary.reload).to be_built_in
    expect(transaction.reload.category_ids).to include(salary.id)
    expect(user.categories.where(category_name: %w[SALARY SALARIO], parent_category_id: nil).count).to eq(1)
  end

  it "creates the Portuguese salary built-in when missing and can be rerun" do
    user = create(:user, :random, locale: "pt-BR")
    user.categories.where(category_name: "SALARIO").delete_all

    2.times { described_class.new.up }

    expect(user.categories.where(category_name: "SALARIO", built_in: true, parent_category_id: nil).count).to eq(1)
    expect(user.categories.where(category_name: [ "OTHER", "OTHER INCOME" ], built_in: true).count).to eq(2)
  end

  it "stops for a user who has both salary keys instead of merging them" do
    user = create(:user, :random)
    create(:category, user:, category_name: "SALARIO")

    expect { described_class.new.up }.to raise_error(RuntimeError, /both SALARY and SALARIO/)
  end
end
