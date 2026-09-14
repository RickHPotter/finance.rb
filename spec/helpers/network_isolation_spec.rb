# frozen_string_literal: true

require "rails_helper"
require "net/http"

RSpec.describe "RSpec network isolation" do
  it "rejects unstubbed external HTTP with the attempted destination" do
    expect { Net::HTTP.get(URI("https://unapproved.example.test/path")) }
      .to raise_error(WebMock::NetConnectNotAllowedError, /unapproved\.example\.test/)
  end

  it "allows explicitly stubbed HTTP without opening a connection" do
    stub_request(:get, "https://approved.example.test/path").to_return(body: "approved")

    expect(Net::HTTP.get(URI("https://approved.example.test/path"))).to eq("approved")
  end
end
