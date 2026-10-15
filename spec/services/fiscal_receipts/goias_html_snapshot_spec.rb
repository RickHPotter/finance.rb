# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::GoiasHtmlSnapshot do
  it "keeps the receipt content readable without remote assets or executable markup" do
    markup = <<~HTML
      <html>
        <link rel="stylesheet" href="Estilos/xslt.css">
        <body>
          <script>alert('external')</script>
          <img src="../resources/logo.png" onload="alert('image')">
          <fieldset><legend>Formas de Pagamento</legend>
            <table><tr><td onclick="alert('cell')"><label>Forma</label><span>Cartão de Crédito</span></td></tr></table>
          </fieldset>
        </body>
      </html>
    HTML

    html = described_class.new(markup, title: "NFC-e detalhada", access_key: "1234").call
    document = Nokogiri::HTML(html)

    expect(document.text).to include("Formas de Pagamento", "Cartão de Crédito", "1234")
    expect(html).to include("<style>")
    expect(document.css("script, link, img, [src], [href], [onclick]")).to be_empty
    expect(html).not_to include("alert(", "xslt.css", "logo.png")
  end
end
