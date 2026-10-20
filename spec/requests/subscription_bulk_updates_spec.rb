# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscription bulk updates", type: :request do
  let(:user) { create(:user, :random) }
  let(:first) { create(:subscription, user:, context: user.main_context) }
  let(:second) { create(:subscription, user:, context: user.main_context) }

  before { sign_in user }

  it "renders an explicit selection control and one bulk form on desktop and PWA" do
    subscription = first

    [ {}, { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" } ].each do |request_headers|
      get subscriptions_path, headers: request_headers
      document = Nokogiri::HTML.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(document.css("form#subscription_bulk_form").size).to eq(1)
      expect(document.at_css("input[name='subscription_ids[]'][value='#{subscription.id}']")&.[]("form")).to eq("subscription_bulk_form")
      expect(document.at_css("select[name='bulk_action']")).to be_present
    end
  end

  def bulk_update(ids:, action:, value: nil)
    patch bulk_update_subscriptions_path, params: { subscription_ids: ids, bulk_action: action, bulk_value: value }
  end

  it "applies a status transition to every selected row in one audit operation" do
    ids = [ first.id, second.id ]

    expect { bulk_update(ids:, action: "status", value: "pause") }.to change(AuditOperation, :count).by(1)

    expect(response).to redirect_to(subscriptions_path)
    expect([ first.reload.status, second.reload.status ]).to eq(%w[paused paused])
    operation = AuditOperation.order(:created_at, :id).last
    expect(operation.metadata["subscription_bulk_edit"]).to eq("status")
    expect(operation.audit_versions.where(item_subtype: "Subscription").pluck(:item_id)).to match_array(ids)
  end

  it "returns to the filtered index after a bulk update" do
    destination = subscriptions_path(search_term: "rent")

    patch bulk_update_subscriptions_path, params: {
      subscription_ids: [ first.id ], bulk_action: "status", bulk_value: "pause", return_to: destination
    }

    expect(response).to redirect_to(destination)
  end

  it "rejects the entire batch if a lifecycle event is invalid for one row" do
    first.id
    second.update!(status: :finished)

    expect { bulk_update(ids: [ first.id, second.id ], action: "status", value: "pause") }.not_to change(AuditOperation, :count)

    expect(first.reload).to be_active
    expect(second.reload).to be_finished
  end

  it "replaces the optional category without changing the main or kind" do
    category = create(:category, :random, user:)
    subscription = first
    original_main = subscription.main_category

    bulk_update(ids: [ subscription.id ], action: "replace_category", value: category.id)

    expect(response).to redirect_to(subscriptions_path)
    expect(subscription.reload.categories).to contain_exactly(category)
    expect(subscription.main_category).to eq(original_main)
    expect(subscription).to be_expense

    bulk_update(ids: [ subscription.id ], action: "clear_category")
    expect(subscription.reload.categories).to be_empty
    expect(subscription.main_category).to eq(original_main)
  end

  it "updates linked transaction allocations along with the optional category" do
    category = create(:category, :random, user:)
    account = create(:user_bank_account, :random, user:)
    transaction = create(:cash_transaction, user:, subscription: first, user_bank_account: account, price: -2500)

    bulk_update(ids: [ first.id ], action: "replace_category", value: category.id)

    expect(first.reload.categories).to contain_exactly(category)
    expect(transaction.reload.category_ids).to contain_exactly(first.main_category_id, category.id)
    expect(transaction.price).to eq(-2500)
  end

  it "does not create an audit operation for a no-op allocation replacement" do
    category = create(:category, :random, user:)
    first.categories << category

    expect { bulk_update(ids: [ first.id ], action: "replace_category", value: category.id) }.not_to change(AuditOperation, :count)
  end

  it "replaces and explicitly clears the entity allocation" do
    entity = create(:entity, :random, user:)

    bulk_update(ids: [ first.id ], action: "replace_entity", value: entity.id)
    expect(first.reload.entities).to contain_exactly(entity)

    bulk_update(ids: [ first.id ], action: "clear_entity")
    expect(first.reload.entities).to be_empty
  end

  it "rejects unsupported actions and values" do
    bulk_update(ids: [ first.id ], action: "main_category", value: user.built_in_category("OTHER").id)
    expect(first.reload.main_category.category_name).to eq("SUBSCRIPTION")

    bulk_update(ids: [ first.id ], action: "clear_category", value: "unexpected")
    expect(first.reload).to be_active
  end

  it "rejects duplicate, foreign-context, and oversized selections" do
    other_context = create(:context, user:)
    foreign = create(:subscription, user:, context: other_context)

    [ [ first.id, first.id ], [ first.id, foreign.id ], (1..101).to_a ].each do |ids|
      bulk_update(ids:, action: "status", value: "pause")
      expect(first.reload).to be_active
    end
  end

  it "rejects a foreign allocation value and leaves all selected rows unchanged" do
    foreign_category = create(:user, :random).built_in_category("OTHER")

    bulk_update(ids: [ first.id, second.id ], action: "replace_category", value: foreign_category.id)

    expect(first.reload.categories).to be_empty
    expect(second.reload.categories).to be_empty
  end
end
