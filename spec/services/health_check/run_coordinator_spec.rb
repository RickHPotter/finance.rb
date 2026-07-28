# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::RunCoordinator do
  let(:admin) { create(:user, :random, admin: true) }
  let(:scope) { HealthCheck::Scope.new(user: admin, context: admin.main_context) }

  before do
    allow(HealthCheck::Broadcaster).to receive(:call)
  end

  it "queues one independent latest row and job for every registered check" do
    schedules = nil

    expect do
      schedules = described_class.new(scope:).call
    end.to have_enqueued_job(HealthCheck::RunJob).exactly(HealthCheck::Registry.entries.count).times

    expect(schedules).to all(be_enqueued)
    expect(admin.health_check_runs.pluck(:check_key)).to contain_exactly(*HealthCheck::Registry.keys)
    expect(admin.health_check_runs).to all(have_attributes(execution_state: "queued", outcome: nil))
    expect(HealthCheck::Broadcaster).to have_received(:call).exactly(HealthCheck::Registry.entries.count).times
  end

  it "does not duplicate a queued or running execution" do
    entry = HealthCheck::Registry.fetch("exchange_return")
    first = described_class.new(scope:).call(entries: [ entry ]).first
    clear_enqueued_jobs
    first.run.update_columns(execution_state: "running")

    second = nil
    expect do
      second = described_class.new(scope:).call(entries: [ entry ]).first
    end.not_to have_enqueued_job(HealthCheck::RunJob)

    expect(second).not_to be_enqueued
    expect(second.reason).to eq("already_running")
    expect(second.run.generation_token).to eq(first.run.generation_token)
    expect(admin.health_check_runs.where(check_key: entry.key).count).to eq(1)
  end

  it "assigns a new generation and clears terminal data on rerun" do
    entry = HealthCheck::Registry.fetch("exchange_return")
    old_run = create_completed_run(entry.key)
    old_token = old_run.generation_token

    schedule = described_class.new(scope:).call(entries: [ entry ]).first
    run = schedule.run.reload

    expect(schedule).to be_enqueued
    expect(run.id).to eq(old_run.id)
    expect(run.generation_token).not_to eq(old_token)
    expect(run).to have_attributes(
      execution_state: "queued",
      outcome: nil,
      started_at: nil,
      finished_at: nil,
      duration_ms: nil,
      error_code: nil
    )
    expect(run.counts.values).to all(be_zero)
  end

  it "ignores a selected connection for context-only checks and retains it for relationship checks" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    selected_scope = HealthCheck::Scope.new(user: admin, context: admin.main_context, connected_user:)
    entries = [
      HealthCheck::Registry.fetch("exchange_return"),
      HealthCheck::Registry.fetch("exchange_trio")
    ]

    described_class.new(scope: selected_scope).call(entries:)

    expect(admin.health_check_runs.find_by!(check_key: "exchange_return").connected_user_id).to be_nil
    expect(admin.health_check_runs.find_by!(check_key: "exchange_trio").connected_user_id).to eq(connected_user.id)
  end

  it "marks the latest generation unavailable when the queue adapter rejects it" do
    entry = HealthCheck::Registry.fetch("exchange_return")
    enqueue_error = ActiveJob::EnqueueError.new("queue offline")
    allow(HealthCheck::RunJob).to receive(:perform_later).and_raise(enqueue_error)
    allow(Rails.error).to receive(:report)

    schedule = described_class.new(scope:).call(entries: [ entry ]).first

    expect(schedule).not_to be_enqueued
    expect(schedule.reason).to eq("enqueue_failed")
    expect(schedule.run.reload).to have_attributes(execution_state: "unavailable", error_code: "enqueue_failed")
    expect(Rails.error).to have_received(:report).with(
      enqueue_error,
      handled: true,
      severity: :error,
      context: hash_including(component: "health_check_coordinator", check_key: entry.key)
    )
  end

  def create_completed_run(check_key)
    HealthCheckRun.create!(
      user: admin,
      context: admin.main_context,
      check_key:,
      execution_state: "completed",
      outcome: "failing",
      counts: { affected: 2, failures: 2 },
      started_at: 1.second.ago,
      finished_at: Time.current,
      duration_ms: 1_000
    )
  end
end
