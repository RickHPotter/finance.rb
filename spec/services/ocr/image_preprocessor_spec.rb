# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ocr::ImagePreprocessor do
  describe "#call" do
    let(:image_path) { Rails.root.join("spec/fixtures/files/ocr_naruto_08/clear_cupom.jpg").to_s }

    it "raises UnsupportedFormat if the file does not exist" do
      expect do
        described_class.new("/nonexistent/file.jpg").call
      end.to raise_error(Ocr::ImagePreprocessor::UnsupportedFormat, I18n.t("ocr.errors.file_missing"))
    end

    it "raises UnsupportedFormat if the file exceeds MAX_FILE_SIZE" do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(15.megabytes)

      expect do
        described_class.new(image_path).call
      end.to raise_error(Ocr::ImagePreprocessor::UnsupportedFormat, I18n.t("ocr.errors.file_too_large"))
    end

    it "raises UnsupportedFormat when preprocessing times out" do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(1.megabyte)
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)

      expect do
        described_class.new(image_path).call
      end.to raise_error(Ocr::ImagePreprocessor::UnsupportedFormat, I18n.t("ocr.errors.preprocessing_timeout"))
    end

    vips_available = begin
      require "vips"
      true
    rescue LoadError
      false
    end

    it "processes an image using Vips when available", skip: !vips_available && "libvips not installed on host" do
      result = described_class.new(image_path).call
      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(File.exist?(result.first)).to be(true)
    ensure
      result&.each { |path| FileUtils.rm_f(path) }
    end
  end
end
