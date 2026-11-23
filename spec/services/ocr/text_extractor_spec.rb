# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ocr::TextExtractor do
  describe "#call" do
    let(:tsv_fixture) do
      <<~TSV
        level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
        1\t1\t0\t0\t0\t0\t0\t0\t600\t800\t-1\t
        2\t1\t1\t0\t0\t0\t10\t10\t580\t780\t-1\t
        3\t1\t1\t1\t0\t0\t10\t10\t580\t50\t-1\t
        4\t1\t1\t1\t1\t0\t10\t10\t580\t20\t-1\t
        5\t1\t1\t1\t1\t1\t10\t10\t100\t20\t95.0\tMERCADO
        5\t1\t1\t1\t1\t2\t115\t10\t80\t20\t91.0\tTESTE
        4\t1\t1\t1\t2\t0\t10\t35\t580\t20\t-1\t
        5\t1\t1\t1\t2\t1\t10\t35\t60\t20\t88.0\tTOTAL
        5\t1\t1\t1\t2\t2\t75\t35\t50\t20\t92.0\t50,00
      TSV
    end

    let(:image_path) { Rails.root.join("spec/fixtures/files/ocr_naruto_08/clear_cupom.jpg").to_s }

    it "parses TSV output correctly combining words into lines and bounding boxes" do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return([ tsv_fixture, "", status ])

      result = described_class.new(image_path).call

      expect(result[:engine]).to eq("tesseract")
      expect(result[:language]).to eq("por+eng")
      expect(result[:lines].size).to eq(2)

      first_line = result[:lines][0]
      expect(first_line[:text]).to eq("MERCADO TESTE")
      expect(first_line[:confidence]).to eq(93.0)
      expect(first_line[:bbox]).to eq([ 10, 10, 185, 20 ])

      second_line = result[:lines][1]
      expect(second_line[:text]).to eq("TOTAL 50,00")
      expect(second_line[:confidence]).to eq(90.0)
    end

    it "raises EngineNotFound when tesseract binary is not installed" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect do
        described_class.new(image_path).call
      end.to raise_error(Ocr::TextExtractor::EngineNotFound, I18n.t("ocr.errors.engine_not_found"))
    end

    it "raises ExtractionTimeout when extraction times out" do
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)

      expect do
        described_class.new(image_path).call
      end.to raise_error(Ocr::TextExtractor::ExtractionTimeout, I18n.t("ocr.errors.extraction_timeout"))
    end

    it "raises ExtractionError when command fails" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return([ "", "Failed to load image", status ])

      expect do
        described_class.new(image_path).call
      end.to raise_error(Ocr::TextExtractor::ExtractionError, /Failed to load image/)
    end

    it "raises ExtractionError when text output is empty" do
      empty_tsv = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n"
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return([ empty_tsv, "", status ])

      expect do
        described_class.new(image_path).call
      end.to raise_error(Ocr::TextExtractor::ExtractionError, I18n.t("ocr.errors.empty_output"))
    end
  end
end
