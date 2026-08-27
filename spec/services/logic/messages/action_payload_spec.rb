# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Messages::ActionPayload do
  it "captures a deeply immutable payload and its precondition data" do
    payload = described_class.new(
      {
        version: "message_notification_v2",
        event: { action: "update" },
        replay: { id: 123, type: "CashTransaction", category_ids: [ 4 ] }
      }.to_json
    )

    expect(payload).to be_valid
    expect(payload.replay).to include("id" => 123, "type" => "CashTransaction")
    expect { payload.replay["category_ids"] << 5 }.to raise_error(FrozenError)
  end

  it "bounds malformed and structurally invalid payloads without raising" do
    malformed = described_class.new("{not-json")
    non_object = described_class.new("[]")
    missing_replay = described_class.new({ version: "message_notification_v2", event: { action: "create" } }.to_json)
    malformed_event = described_class.new({ version: "message_notification_v2", event: "create" }.to_json)

    expect(malformed).to have_attributes(valid?: false, error: :malformed_json)
    expect(non_object).to have_attributes(valid?: false, error: :payload_not_an_object)
    expect(missing_replay).to have_attributes(valid?: false, error: :missing_replay)
    expect(malformed_event).to have_attributes(valid?: false, error: :missing_event)
  end
end
