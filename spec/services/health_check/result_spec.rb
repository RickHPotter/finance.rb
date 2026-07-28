# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Result do
  let(:started_at) { Time.current }
  let(:finished_at) { started_at + 0.125.seconds }
  let(:scope) { { user_id: 12, context_id: 34, connected_user_id: nil, locale: "en" } }

  def build_result(**attributes)
    described_class.new(check_key: "exchange_return",
                        outcome: "failing",
                        severity: "error",
                        scope:,
                        counts: { affected: 2, failures: 2 },
                        started_at:,
                        finished_at:,
                        duration_ms: 125, **attributes)
  end

  it "normalizes registered identifiers and missing counts into an immutable result" do
    result = build_result

    expect(result).to be_failing
    expect(result).not_to be_healthy
    expect(result.counts).to eq(
      "affected" => 2,
      "failures" => 2,
      "warnings" => 0,
      "repairable" => 0,
      "read_only" => 0,
      "unavailable_actions" => 0
    )
    expect(result).to be_frozen
    expect(result.counts).to be_frozen
    expect(result.scope).to be_frozen
  end

  it "accepts every completed outcome" do
    expect(build_result(outcome: :healthy)).to be_healthy
    expect(build_result(outcome: :warning)).to be_warning
    expect(build_result(outcome: :failing)).to be_failing
  end

  it "rejects an unregistered key, outcome, or severity" do
    expect { build_result(check_key: "unknown") }.to raise_error(ArgumentError, "invalid check_key")
    expect { build_result(outcome: "unavailable") }.to raise_error(ArgumentError, "invalid outcome")
    expect { build_result(severity: "critical") }.to raise_error(ArgumentError, "invalid severity")
  end

  it "rejects record objects and invalid identifiers in the scope payload" do
    user = create(:user, :random)

    expect { build_result(scope: { user_id: user, context_id: 34 }) }.to raise_error(ArgumentError, "invalid scope")
    expect { build_result(scope: { user_id: 12, context_id: 0 }) }.to raise_error(ArgumentError, "invalid scope")
    expect { build_result(scope: { user_id: 12, context_id: 34, raw_record: user }) }.to raise_error(ArgumentError, "invalid scope")
  end

  it "rejects unknown, negative, or noninteger counts" do
    expect { build_result(counts: { record: "raw" }) }.to raise_error(ArgumentError, "invalid counts")
    expect { build_result(counts: { failures: -1 }) }.to raise_error(ArgumentError, "invalid counts")
    expect { build_result(counts: { failures: 1.5 }) }.to raise_error(ArgumentError, "invalid counts")
  end

  it "rejects invalid timing and error metadata" do
    expect { build_result(finished_at: started_at - 1.second) }.to raise_error(ArgumentError, "invalid finished_at")
    expect { build_result(duration_ms: -1) }.to raise_error(ArgumentError, "invalid duration_ms")
    expect { build_result(error_code: "SQL failed") }.to raise_error(ArgumentError, "invalid error_code")
  end
end
