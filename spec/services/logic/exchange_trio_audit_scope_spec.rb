# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeTrioAudit, "#visible_conversation_scope" do
  let(:admin) { create(:user, :random, admin: true) }
  let(:selected_user) { create(:user, :random) }
  let(:other_connected_user) { create(:user, :random) }
  let(:unrelated_user) { create(:user, :random) }
  let(:context) { create(:context, user: admin) }

  before do
    admin.entities.create!(entity_name: "SELECTED", entity_user: selected_user)
    admin.entities.create!(entity_name: "OTHER CONNECTED", entity_user: other_connected_user)
  end

  it "keeps all-connections diagnosis inside the selected scenario and known relationships" do
    selected = Conversation.find_or_create_assistant_between!(admin, selected_user, scenario_key: context.scenario_key)
    other_connected = Conversation.find_or_create_assistant_between!(admin, other_connected_user, scenario_key: context.scenario_key)
    Conversation.find_or_create_assistant_between!(admin, selected_user)
    Conversation.find_or_create_assistant_between!(admin, unrelated_user, scenario_key: context.scenario_key)

    service = described_class.new(current_user: admin, current_context: context)

    expect(service.send(:visible_conversation_scope).pluck(:id)).to contain_exactly(selected.id, other_connected.id)
  end

  it "narrows diagnosis to one validated connected-user pair" do
    selected = Conversation.find_or_create_assistant_between!(admin, selected_user, scenario_key: context.scenario_key)
    Conversation.find_or_create_assistant_between!(admin, other_connected_user, scenario_key: context.scenario_key)

    service = described_class.new(
      current_user: admin,
      current_context: context,
      connected_user_id: selected_user.id
    )

    expect(service.send(:visible_conversation_scope).pluck(:id)).to eq([ selected.id ])
  end

  it "returns no conversations for an unrelated selected user" do
    Conversation.find_or_create_assistant_between!(admin, unrelated_user, scenario_key: context.scenario_key)

    service = described_class.new(
      current_user: admin,
      current_context: context,
      connected_user_id: unrelated_user.id
    )

    expect(service.send(:visible_conversation_scope)).to be_empty
  end

  it "rejects a current-user source from another context" do
    transaction = create(:cash_transaction, user: admin, context: admin.main_context)
    service = described_class.new(current_user: admin, current_context: context)

    expect(service.send(:source_context_visible?, transaction)).to be(false)
  end
end
