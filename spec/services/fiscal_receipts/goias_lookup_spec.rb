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
  let(:detailed_html) do
    markup = <<~HTML
      <fieldset><legend>Dados Gerais</legend>
        <table><tr><td><label>Chave de Acesso</label><span>#{key}</span></td></tr></table>
      </fieldset>
      <fieldset><legend>Formas de Pagamento</legend>
        <table><tr><td><label>Forma</label><span>Cartão de Crédito</span></td></tr></table>
      </fieldset>
    HTML
    "new XmlNFE('#xml-nfe-container', '/images/', '#{markup.to_json[1..-2]}');"
  end

  it "uses the signed QR and its consultation session to import Goiás item rows" do
    landing = "<iframe class='iframe-danfe-nfce' src='/nfeweb/sites/nfce/render/danfeNFCe?chNFe=#{key}'></iframe>"
    stub_request(:get, /#{Regexp.escape(described_class::PATH)}\?/).to_return(status: 200, body: landing,
                                                                              headers: { "Set-Cookie" => "JSESSIONID=receipt-session; Path=/nfeweb" })
    embedded = receipt_html.to_json[1..-2]
    detail = "new DanfeNFCe('#receipt', '/images/', '#{embedded}');"
    detail_request = stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/).with(headers: { "Cookie" => "JSESSIONID=receipt-session" })
                                                                                           .to_return(status: 200, body: detail)
    detailed_request = stub_request(:get, /#{Regexp.escape(described_class::DETAILED_PAGE_PATH)}\?/)
                       .with(headers: { "Cookie" => "JSESSIONID=receipt-session" })
                       .to_return(status: 200, body: detailed_html)

    draft = described_class.new(url).call

    expect(detail_request).to have_been_requested
    expect(detailed_request).to have_been_requested
    expect(draft.as_json).to include(access_key: key, issuer: "Mercado Exemplo", total_cents: 1570, source: "sefaz_go")
    expect(draft.items).to eq([ { description: "Arroz", price_cents: 1250 }, { description: "Feijão", price_cents: 320 } ])
  end

  it "imports a version 3 QR URL while preserving its base64 signature" do
    version_three_payload = "#{key}|3|1|24|109.95|2|70596315180|Ab+/Cd=="
    version_three_url = "https://#{described_class::HOST}#{described_class::PATH}?p=#{version_three_payload.gsub('|', '%7C')}"
    landing_request = stub_request(:get, "https://#{described_class::HOST}#{described_class::PATH}?#{URI.encode_www_form(p: version_three_payload)}")
                      .to_return(status: 200, body: "<iframe class='iframe-danfe-nfce' src='#{described_class::DETAIL_PATH}?chNFe=#{key}'></iframe>")
    stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/)
      .to_return(status: 200, body: "new DanfeNFCe('#receipt', '/images/', '#{receipt_html.to_json[1..-2]}');")
    stub_request(:get, /#{Regexp.escape(described_class::DETAILED_PAGE_PATH)}\?/).to_return(status: 200, body: detailed_html)

    draft = described_class.new(version_three_url).call

    expect(landing_request).to have_been_requested
    expect(draft.items.first).to eq(description: "Arroz", price_cents: 1250)
  end

  it "accepts the shorter online version 3 QR payload" do
    online_url = "https://#{described_class::HOST}#{described_class::PATH}?p=#{key}%7C3%7C1"
    landing_request = stub_request(:get, "https://#{described_class::HOST}#{described_class::PATH}?#{URI.encode_www_form(p: "#{key}|3|1")}")
                      .to_return(status: 200, body: "<iframe class='iframe-danfe-nfce' src='#{described_class::DETAIL_PATH}?chNFe=#{key}'></iframe>")
    stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/)
      .to_return(status: 200, body: "new DanfeNFCe('#receipt', '/images/', '#{receipt_html.to_json[1..-2]}');")
    stub_request(:get, /#{Regexp.escape(described_class::DETAILED_PAGE_PATH)}\?/).to_return(status: 200, body: detailed_html)

    expect(described_class.new(online_url).call.total_cents).to eq(1570)
    expect(landing_request).to have_been_requested
  end

  it "captures readable, self-contained Goiás HTML pages and derived detailed JSON" do
    landing = "<iframe class='iframe-danfe-nfce' src='#{described_class::DETAIL_PATH}?chNFe=#{key}'></iframe>"
    stub_request(:get, /#{Regexp.escape(described_class::PATH)}\?/).to_return(status: 200, body: landing)
    stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/)
      .to_return(status: 200, body: "new DanfeNFCe('#receipt', '/images/', '#{receipt_html.to_json[1..-2]}');")
    stub_request(:get, /#{Regexp.escape(described_class::DETAILED_PAGE_PATH)}\?/).to_return(status: 200, body: detailed_html)

    lookup = described_class.new(url)
    lookup.call

    expect(lookup.evidence_files.map { |file| file.fetch(:filename) }).to eq(
      %w[goias-nfce-danfe.html goias-nfce-detailed.html goias-nfce-detailed.json]
    )
    danfe, detailed = lookup.evidence_files.first(2).map { |file| file.fetch(:data) }
    expect(danfe).to include("<style>", "Mercado Exemplo", "Arroz", "15,70", key)
    expect(detailed).to include("<style>", "Formas de Pagamento", "Cartão de Crédito", key)
    [ danfe, detailed ].each do |html|
      document = Nokogiri::HTML(html)
      expect(document.at_css("html")&.[]("lang")).to eq("pt-BR")
      expect(document.css("script, link, iframe, img, [src], [href], [onclick]")).to be_empty
    end
    snapshot = JSON.parse(lookup.evidence_files.last.fetch(:data))
    expect(snapshot).to include("access_key" => key, "format" => "goias-nfce-detailed-page-v1")
    expect(snapshot.fetch("tables")).to include(
      a_hash_including("section" => "Formas de Pagamento", "rows" => [ [ { "label" => "Forma", "value" => "Cartão de Crédito" } ] ])
    )
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

  it "does not treat a generic consultation page as detailed evidence" do
    landing = "<iframe class='iframe-danfe-nfce' src='#{described_class::DETAIL_PATH}?chNFe=#{key}'></iframe>"
    stub_request(:get, /#{Regexp.escape(described_class::PATH)}\?/).to_return(status: 200, body: landing)
    stub_request(:get, /#{Regexp.escape(described_class::DETAIL_PATH)}\?/)
      .to_return(status: 200, body: "new DanfeNFCe('#receipt', '/images/', '#{receipt_html.to_json[1..-2]}');")
    stub_request(:get, /#{Regexp.escape(described_class::DETAILED_PAGE_PATH)}\?/).to_return(status: 200, body: "<title>Consulta Pública</title>")

    expect { described_class.new(url).call }.to raise_error(described_class::Unavailable)
  end
end
