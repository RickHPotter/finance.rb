# frozen_string_literal: true

class HealthCheck::RunCoordinator
  Schedule = Data.define(:run, :enqueued, :reason) do
    def enqueued?
      enqueued
    end
  end

  MAX_INSERT_ATTEMPTS = 2

  attr_reader :scope

  def initialize(scope:)
    @scope = scope
  end

  def call(entries: HealthCheck::Registry.entries)
    Array(entries).map do |entry|
      raise HealthCheck::Scope::Invalid, :check_unregistered unless entry.is_a?(HealthCheck::Registry::Entry)

      schedule(entry)
    end
  end

  private

  def schedule(entry)
    entry_scope = scope.for_entry(entry)
    schedule = queue(entry, entry_scope:)
    safe_broadcast(scope: entry_scope, run: schedule.run)
    return schedule unless schedule.enqueued?

    enqueue(schedule, scope: entry_scope)
  end

  def queue(entry, entry_scope:, attempt: 0)
    HealthCheckRun.transaction(requires_new: true) do
      run = locked_run(entry, entry_scope)
      return Schedule.new(run:, enqueued: false, reason: "already_running") if run&.execution_state.in?(%w[queued running])

      run ||= entry_scope.user.health_check_runs.build(
        context: entry_scope.context,
        connected_user: entry_scope.connected_user,
        check_key: entry.key
      )
      reset_to_queued(run)

      Schedule.new(run:, enqueued: true, reason: "queued")
    end
  rescue ActiveRecord::RecordNotUnique
    raise if attempt >= MAX_INSERT_ATTEMPTS

    queue(entry, entry_scope:, attempt: attempt + 1)
  end

  def locked_run(entry, entry_scope)
    HealthCheckRun
      .where(
        user_id: entry_scope.user.id,
        context_id: entry_scope.context.id,
        connected_user_id: entry_scope.connected_user&.id,
        check_key: entry.key
      )
      .lock
      .first
  end

  def reset_to_queued(run)
    run.assign_attributes(
      generation_token: SecureRandom.uuid,
      execution_state: "queued",
      outcome: nil,
      counts: {},
      queued_at: Time.current,
      started_at: nil,
      finished_at: nil,
      duration_ms: nil,
      error_code: nil
    )
    run.save!
  end

  def enqueue(schedule, scope:)
    job = HealthCheck::RunJob.perform_later(**job_arguments(schedule.run, scope:))
    return schedule if job.successfully_enqueued?

    enqueue_failed(schedule, scope:, error: job.enqueue_error)
  rescue StandardError => e
    enqueue_failed(schedule, scope:, error: e)
  end

  def enqueue_failed(schedule, scope:, error:)
    now = Time.current
    scheduled_token = schedule.run.generation_token
    schedule.run.with_lock do
      schedule.run.reload
      if schedule.run.generation_token == scheduled_token && schedule.run.execution_state_queued?
        schedule.run.update_columns(
          execution_state: "unavailable",
          finished_at: now,
          error_code: "enqueue_failed",
          updated_at: now
        )
      end
    end
    report(error, run: schedule.run)
    safe_broadcast(scope:, run: schedule.run.reload)

    Schedule.new(run: schedule.run, enqueued: false, reason: "enqueue_failed")
  end

  def job_arguments(run, scope:)
    {
      run_id: run.id,
      scope: {
        user_id: scope.user.id,
        context_id: scope.context.id,
        connected_user_id: scope.connected_user&.id,
        locale: scope.locale
      },
      check_key: run.check_key,
      generation_token: run.generation_token
    }
  end

  def safe_broadcast(scope:, run:)
    HealthCheck::Broadcaster.call(scope:, run:)
  rescue StandardError => e
    report(e, run:)
  end

  def report(error, run:)
    return unless error.is_a?(Exception)

    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: { component: "health_check_coordinator", run_id: run.id, check_key: run.check_key }
    )
  rescue StandardError
    nil
  end
end
