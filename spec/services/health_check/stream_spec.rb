# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Stream do
  it "isolates names by administrator, context, and connected-user scope" do
    base = described_class.name(user_id: 1, context_id: 2, connected_user_id: nil)
    connected = described_class.name(user_id: 1, context_id: 2, connected_user_id: 3)

    expect(base).to eq("health_check:user:1:context:2:connected:all")
    expect(connected).to eq("health_check:user:1:context:2:connected:3")
    expect(described_class.name(user_id: 4, context_id: 2, connected_user_id: nil)).not_to eq(base)
    expect(described_class.name(user_id: 1, context_id: 5, connected_user_id: nil)).not_to eq(base)
  end
end
