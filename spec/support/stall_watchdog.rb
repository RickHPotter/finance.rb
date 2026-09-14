# frozen_string_literal: true

require "json"

module RSpecPerformance
  class PostgreSQLDiagnostics
    ACTIVITY_SQL = <<~SQL.squish.freeze
      SELECT pid, usename, application_name, state, wait_event_type, wait_event,
             age(clock_timestamp(), query_start)::text AS query_age,
             pg_blocking_pids(pid)::text AS blocking_pids,
             left(query, 500) AS query
      FROM pg_stat_activity
      WHERE datname = current_database()
      ORDER BY query_start NULLS LAST, pid
    SQL
    LOCKS_SQL = <<~SQL.squish.freeze
      SELECT locks.pid, locks.locktype, locks.mode, locks.granted,
             locks.relation::regclass::text AS relation
      FROM pg_locks AS locks
      JOIN pg_stat_activity AS activity ON activity.pid = locks.pid
      WHERE activity.datname = current_database()
      ORDER BY locks.pid, locks.granted, locks.locktype, locks.mode
    SQL

    def call
      connection = ActiveRecord::Base.connection_pool.checkout(1)
      {
        activity: connection.select_all(ACTIVITY_SQL).to_a,
        locks: connection.select_all(LOCKS_SQL).to_a
      }
    rescue StandardError => e
      { error: "#{e.class}: #{e.message}" }
    ensure
      ActiveRecord::Base.connection_pool.checkin(connection) if connection
    end
  end

  class StallReport
    def initialize(output: $stderr, diagnostics: PostgreSQLDiagnostics.new)
      @output = output
      @diagnostics = diagnostics
    end

    def call(example:, elapsed_seconds:)
      output.puts("\n=== RSpec no-progress watchdog ===")
      output.puts("Active example: #{example.fetch(:rerun_argument)}")
      output.puts("Description: #{example.fetch(:full_description)}")
      output.puts("Elapsed: #{elapsed_seconds.round(2)} seconds")
      print_threads
      output.puts("PostgreSQL activity and locks:")
      output.puts(JSON.pretty_generate(diagnostics.call))
      output.flush
    end

    private

    attr_reader :diagnostics, :output

    def print_threads
      Thread.list.each_with_index do |thread, index|
        output.puts("Thread #{index} object_id=#{thread.object_id} status=#{thread.status.inspect}")
        Array(thread.backtrace).each { |line| output.puts("  #{line}") }
      end
    end
  end

  class StallWatchdog
    ENV_KEY = "RSPEC_STALL_TIMEOUT_SECONDS"

    class << self
      def configured_timeout
        value = ENV.fetch(ENV_KEY, nil)
        return if value.blank?

        timeout = Float(value)
        timeout if timeout.positive?
      rescue ArgumentError
        nil
      end
    end

    def initialize(timeout_seconds:, reporter: StallReport.new, cleanup: nil, terminator: nil, clock: nil)
      @timeout_seconds = timeout_seconds
      @reporter = reporter
      @cleanup = cleanup || -> { FeatureBrowser.shutdown! if defined?(FeatureBrowser) }
      @terminator = terminator || -> { Process.kill("TERM", Process.pid) }
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end

    def watch(example)
      mutex = Mutex.new
      condition = ConditionVariable.new
      finished = false
      identity = identity_for(example)
      started_at = clock.call
      monitor = Thread.new do
        timed_out = mutex.synchronize do
          condition.wait(mutex, timeout_seconds) unless finished
          !finished
        end
        report_and_terminate(identity, started_at) if timed_out
      end

      yield
    ensure
      if mutex && condition
        mutex.synchronize do
          finished = true
          condition.broadcast
        end
      end
      monitor&.join
    end

    private

    attr_reader :cleanup, :clock, :reporter, :terminator, :timeout_seconds

    def identity_for(example)
      {
        full_description: example.full_description,
        rerun_argument: example.location_rerun_argument
      }
    end

    def report_and_terminate(identity, started_at)
      reporter.call(example: identity, elapsed_seconds: clock.call - started_at)
      cleanup.call
      terminator.call
    rescue StandardError => e
      warn("RSpec watchdog failed: #{e.class}: #{e.message}")
      terminator.call
    end
  end
end

if (stall_timeout = RSpecPerformance::StallWatchdog.configured_timeout)
  watchdog = RSpecPerformance::StallWatchdog.new(timeout_seconds: stall_timeout)

  RSpec.configure do |config|
    config.around(:example) { |example| watchdog.watch(example) { example.run } }
  end
end
