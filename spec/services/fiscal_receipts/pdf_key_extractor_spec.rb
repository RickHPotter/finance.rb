# frozen_string_literal: true

require "rails_helper"

RSpec.describe FiscalReceipts::PdfKeyExtractor do
  let(:access_key) { "41140978393592000146651000000000031222222235" }

  it "recognizes a printed access key with groups of four digits" do
    text = "Chave de acesso: #{access_key.scan(/.{1,4}/).join(' ')}"

    expect(described_class.key_from_text(text)).to eq(access_key)
  end

  it "rejects a PDF without a valid access key" do
    expect { described_class.key_from_text("Número do cupom: 12345") }.to raise_error(described_class::Unreadable)
  end

  it "uses bounded text extraction for the first three PDF pages" do
    file = instance_double(ActionDispatch::Http::UploadedFile, tempfile: instance_double(Tempfile, path: "/tmp/receipt.pdf"))
    allow(Open3).to receive(:capture3).and_return([ access_key, "", instance_double(Process::Status, success?: true) ])

    expect(described_class.new(file).call).to eq(access_key)
    expect(Open3).to have_received(:capture3).with("pdftotext", "-f", "1", "-l", "3", "-enc", "UTF-8", "/tmp/receipt.pdf", "-")
  end

  it "preserves a line-wrapped Goiás QR URL from PDF text" do
    goias_key = "52260301427744000150650010005752241062577988"
    text = "QR-Code https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe?p=#{goias_key}|2|1|1|8063029A08AC070E0D5C6DDB\n0891AC3F116830AC"

    expect(described_class.source_from_text(text)).to eq(text.delete("\n").split.last)
  end
end
