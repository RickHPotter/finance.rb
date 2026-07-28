# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance resource navigation state" do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:investment_type) { create(:investment_type) }

  it "retains owned budget filters and rejects foreign allocation identifiers" do
    accepted = Navigation::Budgets.new(
      raw: "/budgets?search_term=food&budget[category_id][]=#{category.id}&budget[entity_id][]=#{entity.id}",
      fallback: "/budgets",
      current_user: user,
      current_context: context
    )
    foreign_category = create(:category, :random, user: create(:user, :random))
    rejected = Navigation::Budgets.new(
      raw: "/budgets?budget[category_id]=#{foreign_category.id}",
      fallback: "/budgets",
      current_user: user,
      current_context: context
    )

    expect(accepted).to be_accepted
    expect(accepted.destination).to include("search_term=food", category.id.to_s, entity.id.to_s)
    expect(rejected.destination).to eq("/budgets")
  end

  it "retains owned investment filters and rejects foreign accounts" do
    investment = create(:investment, user:, context:, user_bank_account: bank_account, investment_type:)
    accepted = Navigation::Investments.new(
      raw: "/investments?investment[id][]=#{investment.id}&investment[user_bank_account_id][]=#{bank_account.id}" \
           "&investment[investment_type_id][]=#{investment_type.id}",
      fallback: "/investments",
      current_user: user,
      current_context: context
    )
    foreign_account = create(:user_bank_account, :random, user: create(:user, :random))
    rejected = Navigation::Investments.new(
      raw: "/investments?investment[user_bank_account_id]=#{foreign_account.id}",
      fallback: "/investments",
      current_user: user,
      current_context: context
    )

    expect(accepted).to be_accepted
    expect(accepted.destination).to include(investment.id.to_s, bank_account.id.to_s, investment_type.id.to_s)
    expect(rejected.destination).to eq("/investments")
  end

  it "retains owned subscription filters while stripping unrelated form data" do
    state = Navigation::Subscriptions.new(
      raw: "/subscriptions?search_term=gym&subscription[category_id][]=#{category.id}" \
           "&subscription[entity_id][]=#{entity.id}&subscription[status][]=active&subscription[description]=secret",
      fallback: "/subscriptions",
      current_user: user,
      current_context: context
    )

    expect(state).to be_accepted
    expect(state.destination).to include("search_term=gym", category.id.to_s, entity.id.to_s, "status")
    expect(state.destination).not_to include("description", "secret")
  end
end
