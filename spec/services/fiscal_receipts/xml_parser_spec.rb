# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::XmlParser do
  let(:access_key) { "41140978393592000146651000000000031222222235" }
  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <nfeProc xmlns="http://www.portalfiscal.inf.br/nfe">
        <NFe><infNFe Id="NFe#{access_key}">
          <ide><mod>65</mod><dhEmi>2026-10-14T12:30:00-03:00</dhEmi></ide>
          <emit><xNome>Mercado Exemplo</xNome></emit>
          <det nItem="1"><prod><xProd>Arroz</xProd><vProd>12.50</vProd><vDesc>1.00</vDesc></prod></det>
          <det nItem="2"><prod><xProd>Feijao</xProd><vProd>8.25</vProd></prod></det>
          <total><ICMSTot><vNF>19.75</vNF></ICMSTot></total>
        </infNFe></NFe>
        <protNFe><infProt><cStat>100</cStat></infProt></protNFe>
      </nfeProc>
    XML
  end

  it "produces cent-precise draft rows from an authorized NFC-e" do
    draft = described_class.new(xml).call

    expect(draft.access_key).to eq(access_key)
    expect(draft.issuer).to eq("Mercado Exemplo")
    expect(draft.total_cents).to eq(1975)
    expect(draft.items).to eq([
                                { description: "Arroz", price_cents: 1150 },
                                { description: "Feijao", price_cents: 825 }
                              ])
    expect(draft.difference_cents).to eq(0)
  end

  it "preserves a total mismatch for review" do
    draft = described_class.new(xml.sub("<vNF>19.75</vNF>", "<vNF>20.00</vNF>")).call

    expect(draft.difference_cents).to eq(25)
  end

  it "rejects XML with external entity declarations" do
    unsafe_xml = xml.sub("<nfeProc", '<!DOCTYPE nfeProc [<!ENTITY exploit SYSTEM "file:///etc/passwd">]><nfeProc')

    expect { described_class.new(unsafe_xml).call }.to raise_error(described_class::InvalidDocument)
  end

  it "rejects an unapproved document" do
    expect { described_class.new(xml.sub("<cStat>100</cStat>", "<cStat>101</cStat>")).call }
      .to raise_error(described_class::InvalidDocument, /authorized/)
  end
end
