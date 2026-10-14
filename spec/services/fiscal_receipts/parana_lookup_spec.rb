# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::ParanaLookup do
  let(:access_key) { "41140978393592000146651000000000031222222235" }
  let(:receipt_html) do
    <<~HTML
      <html><body>
        <div id="u20">Mercado Exemplo</div>
        <table id="tabResult">
          <tr><td><span class="txtTit2">Arroz</span></td><td class="txtTit3">Vl. Total 12,50</td></tr>
          <tr><td><span class="txtTit2">Feijao</span></td><td class="txtTit3">Vl. Total 8,25</td></tr>
        </table>
        <div id="linhaTotal"><label>Qtd. total de itens:</label><span class="totalNumb">2</span></div>
        <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb">20,75</span></div>
        <span>Emissão: 14/10/2026 12:30:00 - Via Consumidor</span>
      </body></html>
    HTML
  end

  it "reads item rows from the Paraná public consultation and preserves a total difference" do
    stub_request(:get, "https://www.fazenda.pr.gov.br/nfce/qrcode?p=#{access_key}%7C3%7C1")
      .to_return(status: 200, body: receipt_html, headers: { "Content-Type" => "text/html" })

    draft = described_class.new(access_key).call

    expect(draft.source).to eq("sefaz_pr")
    expect(draft.issuer).to eq("Mercado Exemplo")
    expect(draft.total_cents).to eq(2075)
    expect(draft.difference_cents).to eq(0)
    expect(draft.items.pluck(:price_cents)).to eq([ 1250, 825 ])
  end

  it "rejects a response without item rows" do
    stub_request(:get, /www\.fazenda\.pr\.gov\.br/).to_return(status: 200, body: "<html>CAPTCHA</html>")

    expect { described_class.new(access_key).call }.to raise_error(described_class::Unavailable, /did not provide item details/)
  end

  it "rejects unsupported state keys before making a request" do
    other_state_key = "53140978393592000146651000000000031222222234"

    expect { described_class.new(other_state_key).call }.to raise_error(described_class::Unavailable)
    expect(WebMock).not_to have_requested(:get, /fazenda\.pr\.gov\.br/)
  end
end
