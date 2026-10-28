# frozen_string_literal: true

require "rails_helper"
require "base64"
require "open3"

RSpec.describe "Fiscal receipt import", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    @original_window_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(390, 844)
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  after do
    page.driver.browser.manage.window.resize_to(@original_window_size.width, @original_window_size.height)
  end

  it "prefills an unsaved cash split purchase from fiscal XML" do
    visit cash_transactions_path
    expect(page).to have_css("div[class~='md:hidden'] [data-controller='action-menu'] button[aria-haspopup='menu']")
    expect_mobile_floating_nav_layout("cashFiscalImportModal")
    open_receipt_menu
    expect(page).to have_button(I18n.t("fiscal_import.import_file"), disabled: true)
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    expect(page).to have_button(I18n.t("fiscal_import.import_file"), disabled: false)
    click_button(I18n.t("fiscal_import.import_file"))
    click_button(I18n.t("fiscal_import.continue"))

    expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
    separator_spacing = page.evaluate_script(<<~JS)
      (() => {
        const rows = [...document.querySelectorAll("[data-composite-transaction-target~='row']:not(.hidden)")]
        const firstBottom = rows[0].getBoundingClientRect().bottom
        return {
          before: firstBottom - rows[0].querySelector(".grid").getBoundingClientRect().bottom,
          after: rows[1].querySelector(".grid").getBoundingClientRect().top - firstBottom
        }
      })()
    JS
    expect(separator_spacing.fetch("before")).to be >= 11
    expect((separator_spacing.fetch("before") - separator_spacing.fetch("after")).abs).to be <= 2
    expect(page).to have_field("cash_transaction[description]", with: "Mercado Exemplo")
    expect(page).to have_field("cash_transaction[price]", with: "-R$ 19.75")
    expect(page).to have_field("cash_transaction_date_date_input", with: "2026-10-14")
    expect(page).to have_field("cash_transaction_date_time_input", with: "12:30")
    descriptions = all("[data-composite-transaction-target~='row']:not(.hidden) input[name$='[description]']").map(&:value)
    expect(descriptions).to eq(%w[Arroz Feijao])
    expect(CashTransaction.where(description: "Mercado Exemplo")).not_to exist
  end

  it "prefills an unsaved card split purchase from fiscal XML" do
    card = create(:user_card, :random, user:)
    visit card_transactions_path(user_card_id: card.id)
    expect(page).to have_css("div[class~='md:hidden'] [data-controller='action-menu'] button[aria-haspopup='menu']")
    expect_mobile_floating_nav_layout("cardFiscalImportModal")
    open_receipt_menu
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    expect(page).to have_button(I18n.t("fiscal_import.import_file"), disabled: false)
    click_button(I18n.t("fiscal_import.import_file"))
    click_button(I18n.t("fiscal_import.continue"))

    expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
    expect(page).to have_field("card_transaction[price]", with: "-R$ 19.75")
    expect(page).to have_field("card_transaction_date_date_input", with: "2026-10-14")
    expect(page).to have_field("card_transaction_date_time_input", with: "12:30")
    descriptions = all("[data-composite-transaction-target~='row']:not(.hidden) input[name$='[description]']").map(&:value)
    expect(descriptions).to eq(%w[Arroz Feijao])
    expect(CardTransaction.where(description: "Mercado Exemplo")).not_to exist
  end

  it "saves imported receipts to the cross-device inbox without creating a transaction" do
    visit cash_transactions_path
    open_receipt_menu
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    click_button(I18n.t("fiscal_import.import_file"))
    click_button(I18n.t("fiscal_import.save_for_later"))

    expect(page).to have_css("[data-fiscal-import-target='status']", text: I18n.t("fiscal_import.messages.draft_saved"))
    receipt_draft = user.fiscal_receipt_drafts.sole
    expect(receipt_draft.fiscal_draft).to include("issuer" => "Mercado Exemplo", "total_cents" => 1975)
    expect(receipt_draft.source.blob.filename.to_s).to eq("fiscal_receipt.xml")
    expect(CashTransaction.where(description: "Mercado Exemplo")).not_to exist

    visit cash_transactions_path
    click_button(I18n.t("fiscal_import.open"))
    click_link(I18n.t("fiscal_import.use_saved"))
    expect(page).to have_text("Mercado Exemplo")
    expect(page).to have_text("R$ 19,75")
    expect(page).to have_css("div[class~='lg:grid-cols-2']")
    expect(page).to have_link(I18n.t("fiscal_import.open_cash"))
    expect(page).to have_link(I18n.t("fiscal_import.open_card"))

    page.driver.browser.manage.window.resize_to(1280, 844)
    visit fiscal_receipt_drafts_path
    expect(page).to have_css("div[class~='lg:grid-cols-2']")
    click_link(I18n.t("fiscal_import.open_cash"))
    expect(page).to have_field("cash_transaction[description]", with: "Mercado Exemplo")
    expect(page).to have_field("cash_transaction_date_date_input", with: "2026-10-14")
    expect(page).to have_field("cash_transaction_date_time_input", with: "12:30")
    expect(page).to have_field("fiscal_receipt_draft_id", with: receipt_draft.id.to_s, type: "hidden")
    expect(user.fiscal_receipt_drafts).to contain_exactly(receipt_draft)
    expect(CashTransaction.where(description: "Mercado Exemplo")).not_to exist

    visit fiscal_receipt_drafts_path
    create(:user_card, :random, user:)
    click_link(I18n.t("fiscal_import.open_card"))
    expect(page).to have_field("card_transaction[description]", with: "Mercado Exemplo")
    expect(page).to have_field("card_transaction_date_date_input", with: "2026-10-14")
    expect(page).to have_field("card_transaction_date_time_input", with: "12:30")
    expect(page).to have_field("fiscal_receipt_draft_id", with: receipt_draft.id.to_s, type: "hidden")
  end

  it "provides localized import status messages in desktop and PWA layouts" do
    [ [ "en", :en ], [ "pt-BR", :"pt-BR" ] ].each do |stored_locale, locale|
      user.profile.update!(locale: stored_locale)
      expected_messages = I18n.with_locale(locale) do
        I18n.t("fiscal_import.messages").stringify_keys
      end

      [ 1280, 390 ].each do |width|
        page.driver.browser.manage.window.resize_to(width, 844)
        visit cash_transactions_path
        messages = page.evaluate_script(
          "JSON.parse(document.querySelector('#cashFiscalImportModal [data-controller~=\\\"fiscal-import\\\"]')" \
          ".dataset.fiscalImportMessagesValue)"
        )

        expect(messages).to eq(expected_messages)
      end
    end
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
      visit cash_transactions_path
      open_receipt_menu
      find("[data-fiscal-import-target='file']", visible: :all).attach_file(path)
      expect(page).to have_button(I18n.t("fiscal_import.import_file"), disabled: false)
      click_button(I18n.t("fiscal_import.import_file"))
      click_button(I18n.t("fiscal_import.continue"))

      expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
      expect(page).to have_field("cash_transaction[price]", with: "-R$ 20.75")
      expect(page).to have_field("cash_transaction[receipts][]", type: "hidden")
    end
  end

  it "attaches a generated source manifest when continuing from a key-only lookup" do
    key = "41140978393592000146651000000000031222222235"
    html = <<~HTML
      <div id="u20">Mercado Exemplo</div>
      <table id="tabResult"><tr><td><span class="txtTit2">Arroz</span></td><td class="txtTit3">Vl. Total 12,50</td></tr></table>
      <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb">12,50</span></div>
    HTML
    stub_request(:get, %r{www\.fazenda\.pr\.gov\.br/nfce/qrcode}).to_return(status: 200, body: html)

    visit cash_transactions_path
    open_receipt_menu
    select(I18n.t("fiscal_import.states.parana"), from: "fiscal_import_state")
    find("[data-fiscal-import-target='source']").set(key)
    click_button(I18n.t("fiscal_import.lookup"))
    click_button(I18n.t("fiscal_import.continue"))

    signed_id = find("input[name='cash_transaction[receipts][]']", visible: :all).value
    blob = ActiveStorage::Blob.find_signed!(signed_id)
    expect(blob.filename.to_s).to eq("fiscal-receipt-source.json")
    expect(JSON.parse(blob.download)).to include("format" => "finance-fiscal-receipt-draft-v1")
  end

  it "attaches Goiás page snapshots and detailed JSON when continuing immediately" do
    url = stub_goias_import_with_evidence

    visit cash_transactions_path
    open_receipt_menu
    find("[data-fiscal-import-target='source']").set(url)
    click_button(I18n.t("fiscal_import.lookup"))
    click_button(I18n.t("fiscal_import.continue"))

    signed_ids = all("input[name='cash_transaction[receipts][]']", visible: :all).map(&:value)
    filenames = signed_ids.map { |signed_id| ActiveStorage::Blob.find_signed!(signed_id).filename.to_s }
    expect(filenames).to contain_exactly(
      "fiscal-receipt-source.json", "goias-nfce-danfe.html", "goias-nfce-detailed.html", "goias-nfce-detailed.json"
    )
  end

  it "keeps Goiás page evidence when saving an import for later" do
    url = stub_goias_import_with_evidence

    visit cash_transactions_path
    open_receipt_menu
    find("[data-fiscal-import-target='source']").set(url)
    click_button(I18n.t("fiscal_import.lookup"))
    click_button(I18n.t("fiscal_import.save_for_later"))

    expect(page).to have_css("[data-fiscal-import-target='status']", text: I18n.t("fiscal_import.messages.draft_saved"))
    receipt_draft = user.fiscal_receipt_drafts.sole
    expect(receipt_draft.source.blob.filename.to_s).to eq("fiscal-receipt-source.json")
    expect(receipt_draft.evidence_files.blobs.map { |blob| blob.filename.to_s }).to contain_exactly(
      "goias-nfce-danfe.html", "goias-nfce-detailed.html", "goias-nfce-detailed.json"
    )
  end

  it "does not upload the camera capture when Goiás evidence is available for an immediate transaction" do
    url = stub_goias_import_with_evidence

    visit cash_transactions_path
    open_receipt_menu
    simulate_camera_import(url)
    click_button(I18n.t("fiscal_import.continue"))

    signed_ids = all("input[name='cash_transaction[receipts][]']", visible: :all).map(&:value)
    filenames = signed_ids.map { |signed_id| ActiveStorage::Blob.find_signed!(signed_id).filename.to_s }
    expect(filenames).to contain_exactly("goias-nfce-danfe.html", "goias-nfce-detailed.html", "goias-nfce-detailed.json")
    expect(ActiveStorage::Blob.where(filename: "fiscal-receipt-camera.jpg")).not_to exist
  end

  it "keeps a small source manifest but not the camera capture when saving Goiás evidence for later" do
    url = stub_goias_import_with_evidence

    visit cash_transactions_path
    open_receipt_menu
    simulate_camera_import(url)
    click_button(I18n.t("fiscal_import.save_for_later"))

    expect(page).to have_css("[data-fiscal-import-target='status']", text: I18n.t("fiscal_import.messages.draft_saved"))
    receipt_draft = user.fiscal_receipt_drafts.sole
    expect(receipt_draft.source.blob.filename.to_s).to eq("fiscal-receipt-source.json")
    expect(receipt_draft.evidence_files.blobs.map { |blob| blob.filename.to_s }).to contain_exactly(
      "goias-nfce-danfe.html", "goias-nfce-detailed.html", "goias-nfce-detailed.json"
    )
    expect(ActiveStorage::Blob.where(filename: "fiscal-receipt-camera.jpg")).not_to exist
  end

  it "keeps the camera capture when consultation provides no replacement evidence" do
    url = stub_goias_import_with_evidence
    allow(FiscalReceipts::GoiasLookup.new(url)).to receive(:evidence_files).and_return([])

    visit cash_transactions_path
    open_receipt_menu
    simulate_camera_import(url)
    click_button(I18n.t("fiscal_import.save_for_later"))

    expect(page).to have_css("[data-fiscal-import-target='status']", text: I18n.t("fiscal_import.messages.draft_saved"))
    receipt_draft = user.fiscal_receipt_drafts.sole
    expect(receipt_draft.source.blob.filename.to_s).to eq("fiscal-receipt-camera.jpg")
    expect(receipt_draft.evidence_files.blobs).to be_empty
  end

  def stub_goias_import_with_evidence
    key = "52260301427744000150650010005752241062577988"
    url = "https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe?p=#{key}|3|1"
    draft = FiscalReceipts::Draft.new(access_key: key, issuer: "Mercado Exemplo", issued_at: Time.zone.parse("2026-10-14T12:30:00-03:00"),
                                      total_cents: 1250, items: [ { description: "Arroz", price_cents: 1250 } ], source: "sefaz_go")
    evidence_files = [
      { filename: "goias-nfce-danfe.html", content_type: "text/html", data: "<html>DANFE</html>" },
      { filename: "goias-nfce-detailed.html", content_type: "text/html", data: "<html>Detalhada</html>" },
      { filename: "goias-nfce-detailed.json", content_type: "application/json", data: { access_key: key }.to_json }
    ]
    allow(FiscalReceipts::GoiasLookup).to receive(:new).with(url)
                                                       .and_return(instance_double(FiscalReceipts::GoiasLookup, call: draft, evidence_files:))
    url
  end

  def simulate_camera_import(url)
    page.execute_script(<<~JS, url)
      const sourceInput = document.querySelector("[data-fiscal-import-target='source']")
      const element = sourceInput.closest("[data-controller~='fiscal-import']")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "fiscal-import")
      const file = new File(["camera image"], "fiscal-receipt-camera.jpg", { type: "image/jpeg" })
      controller.performImport({ source: arguments[0], file, cameraCapture: true })
    JS
    expect(page).to have_button(I18n.t("fiscal_import.continue"), disabled: false)
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

  def expect_mobile_floating_nav_layout(modal_id)
    expect(page).to have_css(
      "[data-controller='action-menu'][class~='bottom-20'][class~='right-3'] button[aria-haspopup='menu'][class~='h-14'][class~='w-14']"
    )
    expect(page).to have_css("a[data-mobile-scroll-nav='plus'][class~='h-14'][class~='w-14']")
    expect(page).to have_css("a[data-mobile-scroll-nav='top'][class~='bottom-52']", visible: :all)
    expect(page).to have_css("a[data-mobile-scroll-nav='bottom'][class~='bottom-52']", visible: :all)
    expect(page).to have_css("[data-modal-toggle='#{modal_id}']", visible: :all)
    expect(page).to have_css("[data-action-menu-target='menu']", visible: :all)
  end

  def open_receipt_menu
    click_button(I18n.t("fiscal_import.open"))
    expect(page).to have_link(I18n.t("fiscal_import.use_saved"))
    click_button(I18n.t("fiscal_import.import_now"))
  end
end
