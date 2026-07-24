# frozen_string_literal: true

class HealthCheck::DashboardSummary
  DISPLAY_STATES = %w[healthy warning failing running unavailable].freeze

  attr_reader :entry, :run

  def initialize(entry:, run:)
    raise ArgumentError, "invalid registry entry" unless entry.is_a?(HealthCheck::Registry::Entry)
    raise ArgumentError, "run does not match registry entry" if run.present? && run.check_key != entry.key

    @entry = entry
    @run = run
    freeze
  end

  def status
    return "unavailable" if never_run? || run.execution_state_unavailable?
    return "running" if run.execution_state_queued? || run.execution_state_running?

    run.outcome
  end

  def never_run?
    run.nil?
  end

  def reason_code
    return "never_run" if never_run?
    return run.error_code if run.execution_state_unavailable?

    nil
  end

  def count(key)
    run&.counts&.fetch(key.to_s, 0) || 0
  end

  def last_run_at
    return if never_run?

    run.finished_at || run.started_at || run.queued_at
  end
end
