# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Finance resource navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:category) { create(:category, :random, user:) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:investment_type) { create(:investment_type) }

  before { sign_in user }

  it "renders budget, investment, and subscription entry screens only as canonical HTML" do
    budget = create(:budget, user:, context: user.main_context, active: false, budget_categories: [ build(:budget_category, category:) ])
    investment = create(:investment, user:, context: user.main_context, user_bank_account: bank_account, investment_type:)
    subscription = create(:subscription, user:, context: user.main_context)

    [
      budgets_path,
      new_budget_path,
      budget_path(budget),
      edit_budget_path(budget),
      duplicate_budget_path(budget),
      investments_path,
      new_investment_path,
      investment_path(investment),
      edit_investment_path(investment),
      duplicate_investment_path(investment),
      subscriptions_path,
      new_subscription_path,
      subscription_path(subscription),
      edit_subscription_path(subscription)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format entry URLs" do
    {
      budgets_path(format: :turbo_stream) => budgets_path,
      new_budget_path(format: :turbo_stream) => new_budget_path,
      investments_path(format: :turbo_stream) => investments_path,
      new_investment_path(format: :turbo_stream) => new_investment_path,
      subscriptions_path(format: :turbo_stream) => subscriptions_path,
      new_subscription_path(format: :turbo_stream) => new_subscription_path
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "marks visible workflow submitters for top-level replacement while leaving hidden updates local" do
    [ new_budget_path, new_investment_path, new_subscription_path ].each do |path|
      get path
      document = Nokogiri::HTML.parse(response.body)
      visible_submitter = document.at_css("form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']")
      hidden_update = document.css("form input[type='submit']").find { |input| input["value"] == "Update" }

      expect(visible_submitter).to be_present
      expect(hidden_update).to be_present
      expect(hidden_update["data-turbo-frame"]).to be_nil
      expect(hidden_update["data-turbo-action"]).to be_nil
    end
  end
end
