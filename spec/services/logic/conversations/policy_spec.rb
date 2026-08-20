# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::Policy do
  let(:user) { create(:user, :random) }
  let(:friend) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user:, friend:) }
  let(:conversation) { resolve_human_conversation(user, friend) }

  it "scopes access to an accepted friendship and the exact selected scenario" do
    derived_context = create(:context, user:, source_context: user.main_context, name: "Policy scenario")
    create(:context, user: friend, scenario_key: derived_context.scenario_key)
    derived_conversation = resolve_human_conversation(user, friend, scenario_key: derived_context.scenario_key)

    expect(described_class.scope(user:, context: user.main_context)).to contain_exactly(conversation)
    expect(described_class.scope(user:, context: derived_context)).to contain_exactly(derived_conversation)

    friendship.update_columns(state: "blocked")

    expect(described_class.scope(user:, context: user.main_context)).to be_empty
    expect(described_class.scope(user:, context: derived_context)).to be_empty
  end

  it "rechecks friendship state under the row lock before yielding a mutation" do
    policy = described_class.new(conversation:, actor: user, context: user.main_context)
    friendship.update_columns(state: "removed")

    expect { |mutation| policy.with_access(&mutation) }
      .to raise_error(described_class::AccessDenied) { |error| expect(error.reason).to eq(:friendship_unavailable) }
  end

  it "checks current persisted friendship state before allowing a stream broadcast" do
    expect(described_class.stream_allowed?(conversation)).to be(true)

    friendship.update_columns(state: "blocked")

    expect(described_class.stream_allowed?(conversation)).to be(false)
  end
end
