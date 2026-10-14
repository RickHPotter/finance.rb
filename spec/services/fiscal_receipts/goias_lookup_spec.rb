# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::GoiasLookup do
  let(:key) { "52260301427744000150650010005752241062577988" }
  let(:payload) { "#{key}|2|1|1|8063029A08AC070E0D5C6DDB0891AC3F116830AC" }
  let(:url) { "https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe?p=#{payload}" }
  let(:receipt_html) do
    <<~HTML
      <div id="u20">Mercado Exemplo</div>
      <span class="chave">#{key}</span>
      <table id="tabResult">
        <tr><td><span class="txtTit">Arroz</span></td><td><span class="valor">12,50</span></td></tr>
        <tr><td><span class="txtTit">Feijão</span></td><td><span class="valor">3,20</span></td></tr>
      </table>
      <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb">15,70</span></div>
      <strong>Emissão: </strong>19/03/2026 08:19:18
    HTML
  end

  it "uses the signed QR and its consultation session to import Goiás item rows" do
    landing = "<iframe class='iframe-danfe-nfce' src='/nfeweb/sites/nfce/render/danfeNFCe?chNFe=#{key}'></iframe>"
    stub_request(:get, /#{Regexp.escape(described_class::PATH)}\?/).to_return(status: 200, body: landing,
                                                                              headers: { "Set-Cookie" => "JSESSIONID=receipt-session; Path=/nfeweb" })
    embedded = receipt_html.to_json[1..-2]
    detail = "new DanfeNFCe('#receipt', '/images/', '#{embedded}');"
    detail_request = stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/).with(headers: { "Cookie" => "JSESSIONID=receipt-session" })
                                                                                           .to_return(status: 200, body: detail)

    draft = described_class.new(url).call

    expect(detail_request).to have_been_requested
    expect(draft.as_json).to include(access_key: key, issuer: "Mercado Exemplo", total_cents: 1570, source: "sefaz_go")
    expect(draft.items).to eq([ { description: "Arroz", price_cents: 1250 }, { description: "Feijão", price_cents: 320 } ])
  end

  it "rejects a bare GO key and unsigned lookalike URL" do
    expect { described_class.new(key).call }.to raise_error(described_class::Unavailable, /QR URL/)
    expect { described_class.new("https://example.com/nfeweb/sites/nfce/danfeNFCe?p=#{payload}").call }
      .to raise_error(described_class::Unavailable, /QR URL/)
  end

  it "rejects a consultation that does not show the expected receipt" do
    stub_request(:get, /#{Regexp.escape(described_class::PATH)}\?/).to_return(status: 200, body: "<div>QR-Code inválido</div>")

    expect { described_class.new(url).call }.to raise_error(described_class::Unavailable, /rejected/)
  end

  it "rejects item details belonging to another fiscal key" do
    landing = "<iframe class='iframe-danfe-nfce' src='#{described_class::DETAIL_PATH}?chNFe=#{key}'></iframe>"
    stub_request(:get, /#{Regexp.escape(described_class::PATH)}\?/).to_return(status: 200, body: landing)
    embedded = receipt_html.sub(key, "0" * 44).to_json[1..-2]
    stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/).to_return(status: 200, body: "new DanfeNFCe('#receipt', '/images/', '#{embedded}');")

    expect { described_class.new(url).call }.to raise_error(described_class::Unavailable, /different receipt/)
  end
end
