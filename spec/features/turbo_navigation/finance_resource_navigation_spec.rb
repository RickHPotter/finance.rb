# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance resource Turbo navigation", type: :feature do
  let(:user) { create(:user, :random) }
  let(:category) { create(:category, :random, user:) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:investment_type) { create(:investment_type) }

  before { sign_in user }

  it "returns a saved budget edit to its filtered budget index" do
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      active: false,
      budget_categories: [ build(:budget_category, category:) ]
    )
    return_to = canonical_return(
      Navigation::Budgets,
      budgets_path(search_term: budget.description, budget: { category_id: [ category.id ] }),
      budgets_path
    )

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_budget_path(budget, return_to:),
      field_id: "budget_description",
      value: "Canonical budget update",
      record: budget
    )
  end

  it "returns a saved investment edit to its filtered investment index" do
    investment = create(:investment, user:, context: user.main_context, user_bank_account: bank_account, investment_type:)
    return_to = canonical_return(
      Navigation::Investments,
      investments_path(investment: { user_bank_account_id: [ bank_account.id ], investment_type_id: [ investment_type.id ] }),
      investments_path
    )

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_investment_path(investment, return_to:),
      field_id: "investment_description",
      value: "Canonical investment update",
      record: investment
    )
  end

  it "returns a saved subscription edit to its filtered subscription index" do
    subscription = create(:subscription, user:, context: user.main_context, status: :active)
    return_to = canonical_return(
      Navigation::Subscriptions,
      subscriptions_path(search_term: subscription.description, subscription: { status: [ "active" ] }),
      subscriptions_path
    )

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_subscription_path(subscription, return_to:),
      field_id: "subscription_description",
      value: "Canonical subscription update",
      record: subscription
    )
  end

  def exercise_edit_navigation(index_path:, edit_path:, field_id:, value:, record:)
    visit index_path
    page.execute_script("Turbo.visit(arguments[0])", edit_path)
    replace_field field_id, with: value

    expect_workflow_finishing_submitter("form button[type='submit']")
    find("form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(index_path)
    expect(record.reload.description).to eq(value)
    browser_back_to(index_path)
    browser_forward_to(index_path)
    refresh_browser_at(index_path)
  end

  def canonical_return(navigation_class, raw, fallback)
    navigation_class.new(raw:, fallback:, current_user: user, current_context: user.main_context).destination
  end
end
