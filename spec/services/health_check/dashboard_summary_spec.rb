# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::DashboardSummary do
  let(:entry) { HealthCheck::Registry.fetch("exchange_return") }

  it "maps an absent run to unavailable with an explicit never-run reason" do
    summary = described_class.new(entry:, run: nil)

    expect(summary).to have_attributes(status: "unavailable", reason_code: "never_run", never_run?: true)
    expect(summary.count(:affected)).to be_zero
    expect(summary.last_run_at).to be_nil
    expect(summary).to be_frozen
  end

  it "maps queued and running execution states to running" do
    queued = described_class.new(entry:, run: build_run(execution_state: "queued"))
    running = described_class.new(entry:, run: build_run(execution_state: "running"))

    expect(queued.status).to eq("running")
    expect(running.status).to eq("running")
  end

  it "uses the outcome and persisted counts from a completed run" do
    finished_at = Time.current
    run = build_run(
      execution_state: "completed",
      outcome: "warning",
      counts: { "affected" => 3, "warnings" => 2 },
      finished_at:
    )
    summary = described_class.new(entry:, run:)

    expect(summary).to have_attributes(status: "warning", reason_code: nil)
    expect(summary.last_run_at).to be_within(0.000001).of(finished_at)
    expect(summary.count(:affected)).to eq(3)
    expect(summary.count(:failures)).to be_zero
  end

  it "preserves the sanitized reason from an unavailable run" do
    run = build_run(execution_state: "unavailable", error_code: "scope_changed")

    expect(described_class.new(entry:, run:).reason_code).to eq("scope_changed")
  end

  it "rejects a run for another registry entry" do
    run = build_run(check_key: "piggy_bank")

    expect { described_class.new(entry:, run:) }.to raise_error(ArgumentError, "run does not match registry entry")
  end

  def build_run(attributes = {})
    HealthCheckRun.new(
      {
        check_key: entry.key,
        execution_state: "queued",
        counts: {}
      }.merge(attributes)
    )
  end
end
