# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Broadcaster do
  let(:admin) { create(:user, :random, admin: true) }
  let(:scope) { HealthCheck::Scope.new(user: admin, context: admin.main_context) }
  let(:run) do
    HealthCheckRun.create!(
      user: admin,
      context: admin.main_context,
      check_key: "exchange_return"
    )
  end

  it "replaces only the matching scope's card and overview" do
    stream = HealthCheck::Stream.for(scope)
    messages = []

    expect do
      described_class.call(scope:, run:)
    end.to(have_broadcasted_to(stream).twice.with { |payload| messages << payload })

    expect(messages.join).to include('target="health_check_check_exchange_return"', 'target="health_check_overview"')
  end

  it "does not broadcast to another administrator or context stream" do
    other_stream = HealthCheck::Stream.name(user_id: admin.id + 10_000, context_id: admin.main_context.id, connected_user_id: nil)

    expect { described_class.call(scope:, run:) }.not_to have_broadcasted_to(other_stream)
  end

  it "updates every valid connected dashboard when a context-only result changes" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    connected_scope = HealthCheck::Scope.new(user: admin, context: admin.main_context, connected_user:)

    expect { described_class.call(scope:, run:) }.to have_broadcasted_to(HealthCheck::Stream.for(connected_scope)).twice
  end

  it "keeps a relationship result on its selected connection stream" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    connected_scope = HealthCheck::Scope.new(user: admin, context: admin.main_context, connected_user:)
    relationship_run = HealthCheckRun.create!(
      user: admin,
      context: admin.main_context,
      connected_user:,
      check_key: "exchange_trio"
    )

    expect { described_class.call(scope: connected_scope, run: relationship_run) }
      .not_to have_broadcasted_to(HealthCheck::Stream.for(scope))
  end
end
