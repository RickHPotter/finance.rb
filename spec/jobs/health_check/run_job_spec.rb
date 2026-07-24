# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::RunJob, type: :job do
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { admin.main_context }

  before do
    allow(HealthCheck::Broadcaster).to receive(:call)
  end

  it "transitions the matching generation through running to its completed result" do
    run = create_run(check_key: "exchange_return")
    scope = HealthCheck::Scope.new(user: admin, context:)
    result = build_result(scope:, check_key: run.check_key, outcome: "warning", counts: { affected: 3, warnings: 2 })
    use_runner(run.check_key, result:)

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(
      execution_state: "completed",
      outcome: "warning",
      error_code: nil,
      duration_ms: result.duration_ms
    )
    expect(run.counts).to include("affected" => 3, "warnings" => 2)
    expect(HealthCheck::Broadcaster).to have_received(:call).twice
  end

  it "persists a bounded unavailable reason when an adapter is unavailable" do
    run = create_run(check_key: "piggy_bank")
    use_runner(run.check_key, error: HealthCheck::Checks::Pending::AdapterUnavailable.new("pending_adapter"))

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(
      execution_state: "unavailable",
      outcome: nil,
      error_code: "adapter_unavailable"
    )
  end

  it "completes a real registered adapter when its scoped audit has no findings" do
    run = create_run(check_key: "piggy_bank")

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(
      execution_state: "completed",
      outcome: "healthy",
      error_code: nil
    )
    expect(run.counts).to include(
      "affected" => 0,
      "failures" => 0,
      "warnings" => 0,
      "repairable" => 0,
      "read_only" => 0,
      "unavailable_actions" => 0
    )
  end

  it "marks a queued row unavailable when its check is no longer registered" do
    run = create_run(check_key: "exchange_return")
    allow(HealthCheck::Registry).to receive(:find).with(run.check_key).and_return(nil)

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(execution_state: "unavailable", error_code: "check_unregistered")
  end

  it "reports unexpected adapter errors without persisting their message" do
    run = create_run(check_key: "exchange_return")
    internal_error = RuntimeError.new("SELECT private financial payload")
    use_runner(run.check_key, error: internal_error)
    allow(Rails.error).to receive(:report)

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(execution_state: "unavailable", error_code: "execution_failed")
    expect(run.error_code).not_to include("private", "SELECT")
    expect(Rails.error).to have_received(:report).with(
      internal_error,
      handled: true,
      severity: :error,
      context: hash_including(component: "health_check_job", run_id: run.id, check_key: run.check_key)
    )
  end

  it "marks the run unavailable when administrator authorization changes before execution" do
    run = create_run(check_key: "exchange_return")
    admin.update!(admin: false)

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(execution_state: "unavailable", error_code: "admin_required")
  end

  it "marks the run unavailable when its context is archived before execution" do
    derived_context = create(:context, user: admin)
    run = create_run(check_key: "exchange_return", context: derived_context)
    derived_context.update!(archived_at: Time.current)

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(execution_state: "unavailable", error_code: "context_archived")
  end

  it "does not broaden a relationship check when the selected connection disappears" do
    connected_user = create(:user, :random)
    connection = admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    run = create_run(check_key: "exchange_trio", connected_user:)
    connection.destroy!

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(execution_state: "unavailable", error_code: "connected_user_unrelated")
  end

  it "ignores a job whose generation is already stale" do
    run = create_run(check_key: "exchange_return")
    stale_arguments = job_arguments(run)
    run.update_columns(generation_token: SecureRandom.uuid)
    expect(HealthCheck::Checks::ExchangeReturn).not_to receive(:new)

    described_class.perform_now(**stale_arguments)

    expect(run.reload.execution_state).to eq("queued")
    expect(HealthCheck::Broadcaster).not_to have_received(:call)
  end

  it "does not let an old completion overwrite a newer generation" do
    run = create_run(check_key: "exchange_return")
    scope = HealthCheck::Scope.new(user: admin, context:)
    result = build_result(scope:, check_key: run.check_key, outcome: "healthy")
    replacement_token = SecureRandom.uuid
    use_runner(run.check_key) do
      run.update_columns(
        generation_token: replacement_token,
        execution_state: "queued",
        outcome: nil,
        started_at: nil,
        finished_at: nil,
        duration_ms: nil,
        error_code: nil
      )
      result
    end

    described_class.perform_now(**job_arguments(run, generation_token: run.generation_token))

    expect(run.reload).to have_attributes(
      generation_token: replacement_token,
      execution_state: "queued",
      outcome: nil
    )
    expect(HealthCheck::Broadcaster).to have_received(:call).once
  end

  it "rejects a result for a different scope" do
    run = create_run(check_key: "exchange_return")
    wrong_scope = { user_id: admin.id, context_id: context.id + 10_000, connected_user_id: nil, locale: "en" }
    result = build_result(scope: wrong_scope, check_key: run.check_key, outcome: "healthy")
    use_runner(run.check_key, result:)
    allow(Rails.error).to receive(:report)

    described_class.perform_now(**job_arguments(run))

    expect(run.reload).to have_attributes(execution_state: "unavailable", error_code: "invalid_result")
    expect(Rails.error).to have_received(:report).with(
      kind_of(described_class::InvalidResult),
      handled: true,
      severity: :error,
      context: hash_including(run_id: run.id)
    )
  end

  it "lets a successful check complete when another check fails" do
    successful_run = create_run(check_key: "exchange_return")
    failing_run = create_run(check_key: "piggy_bank")
    scope = HealthCheck::Scope.new(user: admin, context:)
    use_runner(successful_run.check_key, result: build_result(scope:, check_key: successful_run.check_key, outcome: "healthy"))
    use_runner(failing_run.check_key, error: RuntimeError.new("adapter failed"))
    allow(Rails.error).to receive(:report)

    described_class.perform_now(**job_arguments(failing_run))
    described_class.perform_now(**job_arguments(successful_run))

    expect(failing_run.reload).to have_attributes(execution_state: "unavailable", error_code: "execution_failed")
    expect(successful_run.reload).to have_attributes(execution_state: "completed", outcome: "healthy")
  end

  def create_run(check_key:, context: self.context, connected_user: nil)
    HealthCheckRun.create!(
      user: admin,
      context:,
      connected_user:,
      check_key:
    )
  end

  def job_arguments(run, generation_token: run.generation_token)
    {
      run_id: run.id,
      scope: {
        user_id: run.user_id,
        context_id: run.context_id,
        connected_user_id: run.connected_user_id,
        locale: "en"
      },
      check_key: run.check_key,
      generation_token:
    }
  end

  def build_result(scope:, check_key:, outcome:, counts: {})
    started_at = Time.current
    HealthCheck::Result.new(
      check_key:,
      outcome:,
      severity: "error",
      scope: scope.respond_to?(:to_h) ? scope.to_h : scope,
      counts:,
      started_at:,
      finished_at: started_at + 0.025.seconds,
      duration_ms: 25
    )
  end

  def use_runner(check_key, result: nil, error: nil, &block)
    adapter = double("health check adapter")
    runner = double("health check runner")
    allow(runner).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:call, &block) if block
    allow(adapter).to receive(:call).and_raise(error) if error
    allow(adapter).to receive(:call).and_return(result) unless block || error
    entry = HealthCheck::Registry.fetch(check_key)
    stubbed_entry = HealthCheck::Registry::Entry.new(**entry.to_h, runner:)
    allow(HealthCheck::Registry).to receive(:find).with(check_key).and_return(stubbed_entry)
  end
end
