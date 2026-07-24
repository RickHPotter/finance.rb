# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::DashboardSnapshot do
  let(:admin) { create(:user, :random, admin: true) }
  let(:connected_user) { create(:user, :random) }

  before do
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
  end

  it "shares context-only results while selecting pair-specific relationship results" do
    context_run = create_completed_run(check_key: "exchange_return", outcome: "healthy")
    selected_pair_run = create_completed_run(check_key: "exchange_trio", outcome: "warning", connected_user:)
    create_completed_run(check_key: "exchange_trio", outcome: "failing")
    scope = HealthCheck::Scope.new(user: admin, context: admin.main_context, connected_user:)

    summaries = described_class.new(scope:).summaries.index_by { |summary| summary.entry.key }

    expect(summaries.fetch("exchange_return").run).to eq(context_run)
    expect(summaries.fetch("exchange_return").status).to eq("healthy")
    expect(summaries.fetch("exchange_trio").run).to eq(selected_pair_run)
    expect(summaries.fetch("exchange_trio").status).to eq("warning")
  end

  def create_completed_run(check_key:, outcome:, connected_user: nil)
    HealthCheckRun.create!(
      user: admin,
      context: admin.main_context,
      connected_user:,
      check_key:,
      execution_state: "completed",
      outcome:,
      counts: {},
      started_at: 1.second.ago,
      finished_at: Time.current,
      duration_ms: 1_000
    )
  end
end
