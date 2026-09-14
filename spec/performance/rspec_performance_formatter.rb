# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module RSpecPerformance
  class Clock
    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def wall
      Time.now.utc
    end
  end

  class Artifact
    SCHEMA_VERSION = 1

    def initialize(path:, clock: Clock.new)
      @path = Pathname(path)
      @active_path = @path.sub_ext(".active.json")
      @clock = clock
      @mutex = Mutex.new
      @examples = {}
      @started_at = clock.wall
      @started_monotonic = clock.monotonic
    end

    def example_started(example)
      data = identity_for(example).merge(
        started_at: clock.wall.iso8601(6),
        started_monotonic: clock.monotonic,
        sql_count: 0,
        cached_sql_count: 0,
        factory_count: 0,
        factories: Hash.new(0)
      )

      mutex.synchronize do
        @current_example_id = example.id
        @first_example_started_at ||= data.fetch(:started_at)
        examples[example.id] = data
        write_json(active_path, active_payload(data))
      end
    end

    def record_sql(payload)
      return if ignored_sql?(payload)

      mutex.synchronize do
        current = examples[@current_example_id]
        next unless current

        if payload[:cached]
          current[:cached_sql_count] += 1
        else
          current[:sql_count] += 1
        end
      end
    end

    def record_factory(payload)
      mutex.synchronize do
        current = examples[@current_example_id]
        next unless current

        name = payload.fetch(:name, :unknown).to_s
        current[:factory_count] += 1
        current[:factories][name] += 1
      end
    end

    def example_finished(example)
      mutex.synchronize do
        data = examples.fetch(example.id)
        result = example.execution_result
        data[:finished_at] = clock.wall.iso8601(6)
        data[:duration_seconds] = decimal(result.run_time)
        data[:status] = result.status.to_s
        data[:exception] = exception_payload(result.exception)
        data.delete(:started_monotonic)
        data[:factories] = data.fetch(:factories).sort.to_h
        @last_example_finished_at = data.fetch(:finished_at)
        @current_example_id = nil
      end
    end

    def finish(summary:, seed:)
      payload = mutex.synchronize do
        {
          schema_version: SCHEMA_VERSION,
          run_id: ENV.fetch("RSPEC_PERFORMANCE_RUN_ID", nil),
          generated_at: clock.wall.iso8601(6),
          seed:,
          suite: suite_payload(summary),
          examples: examples.values
        }
      end

      write_json(path, payload)
      FileUtils.rm_f(active_path)
      payload
    end

    private

    attr_reader :active_path, :clock, :examples, :mutex, :path, :started_at, :started_monotonic

    def active_payload(example)
      {
        schema_version: SCHEMA_VERSION,
        run_id: ENV.fetch("RSPEC_PERFORMANCE_RUN_ID", nil),
        pid: Process.pid,
        suite_started_at: started_at.iso8601(6),
        example: example.except(:started_monotonic, :factories)
      }
    end

    def suite_payload(summary)
      {
        formatter_started_at: started_at.iso8601(6),
        first_example_started_at: @first_example_started_at,
        last_example_finished_at: @last_example_finished_at,
        rspec_finished_at: clock.wall.iso8601(6),
        formatter_elapsed_seconds: decimal(clock.monotonic - started_monotonic),
        load_time_seconds: decimal(summary.load_time),
        examples_duration_seconds: decimal(summary.duration),
        example_count: summary.example_count,
        failure_count: summary.failure_count,
        pending_count: summary.pending_count
      }
    end

    def identity_for(example)
      metadata = example.metadata
      {
        id: example.id,
        description: example.description,
        full_description: example.full_description,
        file_path: metadata[:file_path],
        line_number: metadata[:line_number],
        rerun_argument: example.location_rerun_argument
      }
    end

    def ignored_sql?(payload)
      %w[SCHEMA TRANSACTION].include?(payload[:name].to_s)
    end

    def exception_payload(exception)
      return unless exception

      { class: exception.class.name, message: exception.message }
    end

    def decimal(value)
      value&.round(6)
    end

    def write_json(destination, payload)
      FileUtils.mkdir_p(destination.dirname)
      temporary = Pathname("#{destination}.tmp.#{Process.pid}")
      temporary.write(JSON.pretty_generate(payload))
      File.rename(temporary, destination)
    ensure
      FileUtils.rm_f(temporary) if defined?(temporary)
    end
  end

  class Formatter
    RSpec::Core::Formatters.register self, :example_started, :example_finished, :dump_summary, :close

    def initialize(_output)
      @artifact = Artifact.new(path: ENV.fetch("RSPEC_PERFORMANCE_PROFILE_PATH"))
      @subscriptions = []
    end

    def example_started(notification)
      subscribe!
      artifact.example_started(notification.example)
    end

    def example_finished(notification)
      artifact.example_finished(notification.example)
    end

    def dump_summary(notification)
      artifact.finish(summary: notification, seed: RSpec.configuration.seed)
    end

    def close(_notification)
      subscriptions.each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) }
    end

    private

    attr_reader :artifact, :subscriptions

    def subscribe!
      return if subscriptions.any?

      subscriptions << ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
        artifact.record_sql(payload)
      end
      subscriptions << ActiveSupport::Notifications.subscribe("factory_bot.run_factory") do |_name, _start, _finish, _id, payload|
        artifact.record_factory(payload)
      end
    end
  end
end
