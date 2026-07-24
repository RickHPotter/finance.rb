# frozen_string_literal: true

class HealthCheck::RunJob < ApplicationJob
  class InvalidResult < StandardError; end

  SCOPE_KEYS = %i[user_id context_id connected_user_id locale].freeze

  queue_as :default

  def perform(run_id:, scope:, check_key:, generation_token:)
    assign_arguments(
      run_id:,
      check_key:,
      generation_token:,
      **scope.to_h.symbolize_keys.slice(*SCOPE_KEYS)
    )
    @run = matching_run
    return if @run.blank?

    entry = HealthCheck::Registry.find(check_key)
    return finish_unavailable("check_unregistered") if entry.blank?
    return finish_unavailable("unexpected_connected_user") if connected_user_id.present? && !entry.connection_scoped?

    @scope = build_scope
    return unless transition_to_running

    safe_broadcast
    result = entry.runner.new(scope: @scope).call
    validate_result!(result)
    finish_completed(result)
  rescue HealthCheck::Scope::Invalid => e
    finish_unavailable(e.code)
  rescue HealthCheck::Checks::Pending::AdapterUnavailable
    finish_unavailable("adapter_unavailable")
  rescue InvalidResult => e
    report(e)
    finish_unavailable("invalid_result")
  rescue StandardError => e
    report(e)
    finish_unavailable("execution_failed")
  end

  private

  attr_reader :check_key, :connected_user_id, :context_id, :generation_token, :locale, :run_id, :user_id

  def assign_arguments(**arguments)
    arguments.each { |name, value| instance_variable_set(:"@#{name}", value) }
  end

  def matching_run
    HealthCheckRun.find_by(
      id: run_id,
      user_id:,
      context_id:,
      connected_user_id:,
      check_key:,
      generation_token:
    )
  end

  def build_scope
    user = User.find_by(id: user_id)
    raise HealthCheck::Scope::Invalid, :user_not_found if user.blank?

    context = Context.find_by(id: context_id)
    raise HealthCheck::Scope::Invalid, :context_not_found if context.blank?

    connected_user = connected_user_id.present? ? User.find_by(id: connected_user_id) : nil
    raise HealthCheck::Scope::Invalid, :connected_user_not_found if connected_user_id.present? && connected_user.blank?

    HealthCheck::Scope.new(user:, context:, connected_user:, locale:)
  end

  def transition_to_running
    transition_current?(%w[queued]) do |now|
      {
        execution_state: "running",
        started_at: now,
        finished_at: nil,
        duration_ms: nil,
        error_code: nil,
        updated_at: now
      }
    end
  end

  def finish_completed(result)
    transitioned = transition_current?(%w[running]) do |now|
      {
        execution_state: "completed",
        outcome: result.outcome,
        counts: result.counts,
        started_at: result.started_at,
        finished_at: result.finished_at,
        duration_ms: result.duration_ms,
        error_code: nil,
        updated_at: now
      }
    end
    safe_broadcast if transitioned
  end

  def finish_unavailable(code)
    transitioned = transition_current?(%w[queued running]) do |now|
      {
        execution_state: "unavailable",
        outcome: nil,
        finished_at: now,
        duration_ms: elapsed_duration(now),
        error_code: sanitized_code(code),
        updated_at: now
      }
    end
    safe_broadcast if transitioned && @scope.present?
  end

  def transition_current?(states)
    return false if @run.blank?

    @run.with_lock do
      @run.reload
      return false unless @run.generation_token == generation_token.to_s
      return false unless @run.execution_state.in?(states)

      @run.update_columns(yield(Time.current))
    end
    true
  end

  def validate_result!(result)
    raise InvalidResult, "invalid_result_type" unless result.is_a?(HealthCheck::Result)
    raise InvalidResult, "check_key_mismatch" unless result.check_key == check_key
    raise InvalidResult, "scope_mismatch" unless result.scope == @scope.to_h
    raise InvalidResult, "result_error_code" if result.error_code.present?
    raise InvalidResult, "started_before_queue" if result.started_at < @run.queued_at
  end

  def elapsed_duration(finished_at)
    return if @run.started_at.blank?

    [ ((finished_at - @run.started_at) * 1_000).round, 0 ].max
  end

  def sanitized_code(code)
    normalized = code.to_s
    return normalized if normalized.length <= 100 && normalized.match?(/\A[a-z0-9_]+\z/)

    "execution_failed"
  end

  def safe_broadcast
    HealthCheck::Broadcaster.call(scope: @scope, run: @run.reload)
  rescue StandardError => e
    report(e)
  end

  def report(error)
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: { component: "health_check_job", run_id:, check_key: }
    )
  rescue StandardError
    nil
  end
end
