# frozen_string_literal: true

require "rails_helper"

RSpec.describe RSpecPerformance::StallWatchdog do
  it "collects PostgreSQL activity and lock state without borrowing a connection indefinitely" do
    diagnostics = RSpecPerformance::PostgreSQLDiagnostics.new.call

    expect(diagnostics).to include(activity: be_an(Array), locks: be_an(Array))
    expect(diagnostics.fetch(:activity)).to include(hash_including("state" => a_string_matching(/active|idle/)))
  end

  it "reports a deliberately blocked example before invoking cleanup and termination" do
    output = StringIO.new
    diagnostics = instance_double(RSpecPerformance::PostgreSQLDiagnostics, call: { activity: [ { "state" => "active" } ], locks: [] })
    reporter = RSpecPerformance::StallReport.new(output:, diagnostics:)
    terminated = Queue.new
    cleaned = Queue.new
    release = Queue.new
    example = Struct.new(:full_description, :location_rerun_argument).new("blocked diagnostic example", "./spec/example_spec.rb:12")
    watchdog = described_class.new(
      timeout_seconds: 0.05,
      reporter:,
      cleanup: -> { cleaned << true },
      terminator: -> { terminated << true }
    )

    worker = Thread.new { watchdog.watch(example) { wait_for_signal(release, description: "the blocked watchdog example release") } }

    expect(wait_for_signal(terminated, description: "the watchdog termination callback")).to be(true)
    expect(wait_for_signal(cleaned, description: "the watchdog cleanup callback")).to be(true)
    expect(output.string).to include(
      "RSpec no-progress watchdog",
      "./spec/example_spec.rb:12",
      "blocked diagnostic example",
      "PostgreSQL activity and locks",
      '"state": "active"'
    )
  ensure
    release << true if release
    join_thread(worker, description: "the blocked watchdog example") if worker
  end

  it "stays disabled when its environment setting is absent or invalid" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(described_class::ENV_KEY, nil).and_return(nil, "invalid")

    expect(described_class.configured_timeout).to be_nil
    expect(described_class.configured_timeout).to be_nil
  end
end
