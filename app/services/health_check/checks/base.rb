# frozen_string_literal: true

class HealthCheck::Checks::Base
  attr_reader :scope

  def initialize(scope:)
    @scope = scope
  end

  def call
    started_at = Time.current
    started_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    counts = audit_counts
    finished_at = Time.current

    HealthCheck::Result.new(
      check_key:,
      outcome: outcome_for(counts),
      severity: severity_for(counts),
      scope: scope.to_h,
      counts:,
      started_at:,
      finished_at:,
      duration_ms: duration_ms_since(started_clock),
      error_code: nil
    )
  end

  private

  def audit_counts
    raise NotImplementedError
  end

  def check_key
    self.class::CHECK_KEY
  end

  def outcome_for(counts)
    return "failing" if counts.fetch(:failures, 0).positive?
    return "warning" if counts.fetch(:warnings, 0).positive?

    "healthy"
  end

  def severity_for(counts)
    return "error" if counts.fetch(:failures, 0).positive?
    return "warning" if counts.fetch(:warnings, 0).positive?

    HealthCheck::Registry.fetch(check_key).severity
  end

  def duration_ms_since(started_clock)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_clock
    [ (elapsed * 1000).round, 0 ].max
  end
end
