# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("spec/performance/rspec_performance_formatter")
require "tmpdir"

RSpec.describe RSpecPerformance::Artifact do
  subject(:artifact) { described_class.new(path:, clock:) }

  let(:path) { Pathname(Dir.mktmpdir).join("profile.json") }
  let(:clock) { instance_double(RSpecPerformance::Clock) }
  let(:example) do
    instance_double(
      RSpec::Core::Example,
      id: "./spec/example_spec.rb[1:1]",
      description: "profiles work",
      full_description: "profiling profiles work",
      location_rerun_argument: "./spec/example_spec.rb:12",
      metadata: { file_path: "./spec/example_spec.rb", line_number: 12 },
      execution_result:
    )
  end
  let(:execution_result) { instance_double(RSpec::Core::Example::ExecutionResult, run_time: 0.25, status: :passed, exception: nil) }
  let(:summary) { instance_double(RSpec::Core::Notifications::SummaryNotification, load_time: 0.5, duration: 0.75, example_count: 1, failure_count: 0, pending_count: 0) }

  before do
    allow(clock).to receive(:wall).and_return(
      Time.utc(2026, 9, 14, 12),
      Time.utc(2026, 9, 14, 12, 0, 1),
      Time.utc(2026, 9, 14, 12, 0, 2),
      Time.utc(2026, 9, 14, 12, 0, 3),
      Time.utc(2026, 9, 14, 12, 0, 4)
    )
    allow(clock).to receive(:monotonic).and_return(10.0, 11.0, 14.0)
  end

  it "writes per-example SQL, factory, timing, and suite metadata" do
    artifact.example_started(example)
    artifact.record_sql(name: "CashInstallment Load", cached: false)
    artifact.record_sql(name: "CashInstallment Load", cached: true)
    artifact.record_sql(name: "SCHEMA", cached: false)
    artifact.record_factory(name: :cash_transaction)
    artifact.example_finished(example)
    artifact.finish(summary:, seed: 12_345)

    payload = JSON.parse(path.read)
    profile = payload.fetch("examples").sole

    expect(payload).to include(
      "schema_version" => 1,
      "seed" => 12_345,
      "run_id" => ENV.fetch("RSPEC_PERFORMANCE_RUN_ID", nil)
    )
    expect(payload.fetch("suite")).to include(
      "example_count" => 1,
      "failure_count" => 0,
      "load_time_seconds" => 0.5,
      "examples_duration_seconds" => 0.75
    )
    expect(profile).to include(
      "rerun_argument" => "./spec/example_spec.rb:12",
      "duration_seconds" => 0.25,
      "sql_count" => 1,
      "cached_sql_count" => 1,
      "factory_count" => 1,
      "factories" => { "cash_transaction" => 1 },
      "status" => "passed"
    )
    expect(path.sub_ext(".active.json")).not_to exist
  end

  it "leaves an active-example diagnostic before the suite finishes" do
    artifact.example_started(example)

    active = JSON.parse(path.sub_ext(".active.json").read)

    expect(active.fetch("example")).to include(
      "full_description" => "profiling profiles work",
      "rerun_argument" => "./spec/example_spec.rb:12"
    )
  end
end
