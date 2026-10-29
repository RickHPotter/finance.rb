# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::IdentityToken do
  let(:user) { create(:user, :random) }
  let(:key) { "41140978393592000146651000000000031222222235" }

  it "only accepts an intact identity token for its owner" do
    token = described_class.issue(user:, access_key: key)

    expect(described_class.read(token, user:)).to eq(key)
    expect(described_class.read(token, user: create(:user, :random))).to be_nil
    expect(described_class.read("#{token}x", user:)).to be_nil
    expect { described_class.issue(user:, access_key: "invalid") }.to raise_error(ArgumentError)
  end
end
