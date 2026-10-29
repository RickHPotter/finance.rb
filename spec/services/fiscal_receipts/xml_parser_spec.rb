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
                                { description: "Arroz", price_cents: 1250 },
                                { description: "Feijao", price_cents: 825 }
                              ])
    expect(draft.difference_cents).to eq(0)
    expect(draft.discount_cents).to eq(100)
  end

  it "preserves a total mismatch for review" do
    draft = described_class.new(xml.sub("<vNF>19.75</vNF>", "<vNF>20.00</vNF>")).call

    expect(draft.difference_cents).to eq(25)
  end

  it "preserves a fully discounted product and includes its discount" do
    free_item = "<det nItem=\"3\"><prod><xProd>Free Feijao</xProd><vProd>8.25</vProd><vDesc>8.25</vDesc></prod></det>"
    draft = described_class.new(xml.sub("<total>", "#{free_item}<total>")).call

    expect(draft.items.last).to eq({ description: "Free Feijao", price_cents: 825 })
    expect(draft.discount_cents).to eq(925)
    expect(draft.difference_cents).to eq(0)
  end

  it "rejects XML with external entity declarations" do
    unsafe_xml = xml.sub("<nfeProc", '<!DOCTYPE nfeProc [<!ENTITY exploit SYSTEM "file:///etc/passwd">]><nfeProc')

    expect { described_class.new(unsafe_xml).call }.to raise_error(described_class::InvalidDocument)
  end

  it "rejects an unapproved document" do
    expect { described_class.new(xml.sub("<cStat>100</cStat>", "<cStat>101</cStat>")).call }
      .to raise_error(described_class::InvalidDocument, /authorized/)
  end

  it "retains original model-55 fiscal values separately from the current normalized item" do
    source = Rails.root.join("spec/fixtures/files/fiscal_naruto_07/discount_55.xml").read
    draft = described_class.new(source).call

    expect(draft.total_cents).to eq(10_995)
    expect(draft.fiscal_details[:document_totals]).to include("vProd" => 11_995, "vDesc" => 1000, "vNF" => 10_995)
    expect(draft.fiscal_details[:items].first).to include(quantity: "1.0000", unit_price: "119.95", amounts: include("vProd" => 11_995, "vDesc" => 1000))
  end

  it "reads synthetic model-55 ordinary, freight and unresolved examples" do
    fixtures = Rails.root.join("spec/fixtures/files/fiscal_naruto_07")
    ordinary = described_class.new(fixtures.join("ordinary_55.xml").read).call
    freight = described_class.new(fixtures.join("freight_55.xml").read).call
    unresolved = described_class.new(fixtures.join("unresolved_55.xml").read).call

    expect(ordinary.difference_cents).to eq(0)
    expect(freight.fiscal_details[:document_totals]).to include("vFrete" => 800)
    expect(unresolved.difference_cents).to eq(300)
  end

  it "requires a matching model-55 authorization protocol key" do
    source = Rails.root.join("spec/fixtures/files/fiscal_naruto_07/ordinary_55.xml").read

    expect { described_class.new(source.sub(%r{<chNFe>.*?</chNFe>}, "")).call }.to raise_error(described_class::InvalidDocument, /protocol key/)
    expect { described_class.new(source.sub(%r{<chNFe>.*?</chNFe>}, "<chNFe>#{'0' * 44}</chNFe>")).call }
      .to raise_error(described_class::InvalidDocument, /protocol key/)
  end

  it "rejects conflicting item and document discount totals" do
    source = Rails.root.join("spec/fixtures/files/fiscal_naruto_07/discount_55.xml").read
    source = source.sub("<vProd>119.95</vProd><vDesc>10.00</vDesc><vNF>", "<vProd>119.95</vProd><vDesc>9.00</vDesc><vNF>")

    expect { described_class.new(source).call }.to raise_error(described_class::InvalidDocument, /adjustment totals disagree/)
  end

  it "rejects an inconsistent protocol key for model 65 when one is supplied" do
    source = xml.sub("<cStat>100</cStat>", "<chNFe>#{'0' * 44}</chNFe><cStat>100</cStat>")

    expect { described_class.new(source).call }.to raise_error(described_class::InvalidDocument, /protocol key/)
  end
end
