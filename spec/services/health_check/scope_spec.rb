# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Scope do
  let(:user) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }

  it "captures a frozen identifier-only scope for the selected context" do
    scope = described_class.new(user:, context:, locale: :en)

    expect(scope.to_h).to eq(
      user_id: user.id,
      context_id: context.id,
      connected_user_id: nil,
      locale: "en"
    )
    expect(scope).to be_all_connections
    expect(scope).to be_frozen
    expect(scope.to_h).to be_frozen
  end

  it "accepts one user explicitly connected through the administrator's entity" do
    connected_user = create(:user, :random)
    user.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)

    scope = described_class.new(user:, context:, connected_user:)

    expect(scope.connected_user).to eq(connected_user)
    expect(scope).not_to be_all_connections
    expect(scope.to_h[:connected_user_id]).to eq(connected_user.id)
  end

  it "exposes the selected scenario key" do
    derived_context = create(:context, user:)
    scope = described_class.new(user:, context: derived_context)

    expect(scope.scenario_key).to eq(derived_context.scenario_key)
  end

  it "removes a selected connection from context-only check scopes" do
    connected_user = create(:user, :random)
    user.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    scope = described_class.new(user:, context:, connected_user:)

    context_scope = scope.for_entry(HealthCheck::Registry.fetch("exchange_return"))
    relationship_scope = scope.for_entry(HealthCheck::Registry.fetch("exchange_trio"))

    expect(context_scope).to be_all_connections
    expect(relationship_scope.connected_user).to eq(connected_user)
  end

  it "rejects a non-admin user" do
    user.update!(admin: false)

    expect { described_class.new(user:, context:) }
      .to raise_error(described_class::Invalid) { |error| expect(error.code).to eq("admin_required") }
  end

  it "rejects a context owned by another user" do
    other_user = create(:user, :random)

    expect { described_class.new(user:, context: other_user.main_context) }
      .to raise_error(described_class::Invalid) { |error| expect(error.code).to eq("context_mismatch") }
  end

  it "rejects an archived context" do
    archived_context = create(:context, user:, archived_at: Time.current)

    expect { described_class.new(user:, context: archived_context) }
      .to raise_error(described_class::Invalid) { |error| expect(error.code).to eq("context_archived") }
  end

  it "rejects an unrelated connected user" do
    connected_user = create(:user, :random)

    expect { described_class.new(user:, context:, connected_user:) }
      .to raise_error(described_class::Invalid) { |error| expect(error.code).to eq("connected_user_unrelated") }
  end

  it "rejects an unsupported locale" do
    expect { described_class.new(user:, context:, locale: "xx") }
      .to raise_error(described_class::Invalid) { |error| expect(error.code).to eq("unsupported_locale") }
  end
end
