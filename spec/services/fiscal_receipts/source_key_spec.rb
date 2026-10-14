# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::SourceKey do
  let(:access_key) { "41140978393592000146651000000000031222222235" }

  it "accepts a spaced 44-digit key" do
    expect(described_class.new(access_key.scan(/.{1,4}/).join(" ")).call).to eq(access_key)
  end

  it "extracts the key from an official Paraná QR URL without fetching that URL" do
    url = "http://www.fazenda.pr.gov.br/nfce/qrcode?p=#{access_key}|2|1|1|ABCDEF"

    expect(described_class.new(url).call).to eq(access_key)
  end

  it "rejects an arbitrary URL" do
    expect { described_class.new("https://example.com/nfce/qrcode?p=#{access_key}").call }
      .to raise_error(described_class::InvalidSource)
  end
end
