# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledgers::ExternalRateLimiter, type: :service do
  let(:request) { instance_double(ActionDispatch::Request, remote_ip: "203.0.113.10") }
  let(:store) { ActiveSupport::Cache::MemoryStore.new }

  it "bounds requests by both network and lookup identity without storing the bearer token" do
    raw_token = "raw-secret-ledger-token"
    keys = []
    allow(store).to receive(:increment).and_wrap_original do |method, key, *args, **kwargs|
      keys << key
      method.call(key, *args, **kwargs)
    end
    stub_const("Ledgers::ExternalRateLimiter::NETWORK_LIMIT", 10)
    stub_const("Ledgers::ExternalRateLimiter::IDENTITY_LIMIT", 2)

    expect(described_class.allowed?(request:, token: raw_token, store:)).to be(true)
    expect(described_class.allowed?(request:, token: raw_token, store:)).to be(true)
    expect(described_class.allowed?(request:, token: raw_token, store:)).to be(false)
    expect(keys).not_to include(a_string_including(raw_token))
  end

  it "bounds rotating invalid lookup identities before creating unbounded cache keys" do
    stub_const("Ledgers::ExternalRateLimiter::NETWORK_LIMIT", 2)
    stub_const("Ledgers::ExternalRateLimiter::IDENTITY_LIMIT", 10)

    expect(described_class.allowed?(request:, token: "invalid-one", store:)).to be(true)
    expect(described_class.allowed?(request:, token: "invalid-two", store:)).to be(true)
    expect(described_class.allowed?(request:, token: "invalid-three", store:)).to be(false)

    identity_keys = store.instance_variable_get(:@data).keys.grep(/:identity:/)
    expect(identity_keys.size).to eq(2)
  end

  it "fails open without exposing lookup material when the throttle store is unavailable" do
    allow(store).to receive(:increment).and_raise(IOError)
    allow(Rails.logger).to receive(:warn)

    expect(described_class.allowed?(request:, token: "never-log-this", store:)).to be(true)
    expect(Rails.logger).to have_received(:warn).with("External ledger rate limit unavailable (IOError)")
  end

  it "isolates month-frame fan-out from the stricter navigation budget" do
    stub_const("Ledgers::ExternalRateLimiter::NETWORK_LIMIT", 10)
    stub_const("Ledgers::ExternalRateLimiter::IDENTITY_LIMIT", 2)
    stub_const("Ledgers::ExternalRateLimiter::MONTH_FRAME_NETWORK_LIMIT", 10)
    stub_const("Ledgers::ExternalRateLimiter::MONTH_FRAME_IDENTITY_LIMIT", 3)

    3.times { expect(described_class.allowed?(request:, token: "valid", scope: :month_frame, store:)).to be(true) }
    expect(described_class.allowed?(request:, token: "valid", scope: :month_frame, store:)).to be(false)

    2.times { expect(described_class.allowed?(request:, token: "valid", store:)).to be(true) }
    expect(described_class.allowed?(request:, token: "valid", store:)).to be(false)
  end
end
