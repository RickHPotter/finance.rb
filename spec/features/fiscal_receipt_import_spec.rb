# frozen_string_literal: true

require "rails_helper"
require "base64"
require "open3"

RSpec.describe "Fiscal receipt import", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  it "prefills an unsaved cash split purchase from fiscal XML" do
    visit new_cash_transaction_path
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    find("[data-action='click->fiscal-import#importFile']").click

    expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
    expect(page).to have_field("cash_transaction[description]", with: "Mercado Exemplo")
    expect(page).to have_field("cash_transaction[price]", with: "-R$ 19.75")
    descriptions = all("[data-composite-transaction-target~='row']:not(.hidden) input[name$='[description]']").map(&:value)
    expect(descriptions).to eq(%w[Arroz Feijao])
    expect(CashTransaction.where(description: "Mercado Exemplo")).not_to exist
  end

  it "prefills an unsaved card split purchase from fiscal XML" do
    create(:user_card, :random, user:)
    visit new_card_transaction_path
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    find("[data-action='click->fiscal-import#importFile']").click

    expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
    expect(page).to have_field("card_transaction[price]", with: "-R$ 19.75")
    descriptions = all("[data-composite-transaction-target~='row']:not(.hidden) input[name$='[description]']").map(&:value)
    expect(descriptions).to eq(%w[Arroz Feijao])
    expect(CardTransaction.where(description: "Mercado Exemplo")).not_to exist
  end

  it "reads a Paraná QR code from a receipt image" do
    key = "41140978393592000146651000000000031222222235"
    qr_url = "https://www.fazenda.pr.gov.br/nfce/qrcode?p=#{key}|3|1"
    html = <<~HTML
      <div id="u20">Mercado Exemplo</div>
      <table id="tabResult">
        <tr><td><span class="txtTit2">Arroz</span></td><td class="txtTit3">Vl. Total 12,50</td></tr>
        <tr><td><span class="txtTit2">Feijao</span></td><td class="txtTit3">Vl. Total 8,25</td></tr>
      </table>
      <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb">20,75</span></div>
    HTML
    stub_request(:get, %r{www\.fazenda\.pr\.gov\.br/nfce/qrcode}).to_return(status: 200, body: html)

    with_qr_png(qr_url) do |path|
      visit new_cash_transaction_path
      find("[data-fiscal-import-target='file']", visible: :all).attach_file(path)
      find("[data-action='click->fiscal-import#importFile']").click

      expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
      expect(page).to have_field("cash_transaction[price]", with: "-R$ 20.75")
    end
  end

  def with_qr_png(value)
    data_url, status = Open3.capture2("node", "-e", "require('qrcode').toDataURL(process.argv[1], { width: 500 }).then(console.log)", value)
    raise "Could not generate test QR code" unless status.success?

    Tempfile.create([ "fiscal-receipt-qr", ".png" ]) do |file|
      file.binmode
      file.write(Base64.decode64(data_url.split(",", 2).last))
      file.flush
      yield file.path
    end
  end
end
