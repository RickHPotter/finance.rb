# frozen_string_literal: true

require "open3"
require "timeout"

module Ocr
  class ImagePreprocessor
    class UnsupportedFormat < StandardError; end

    MAX_FILE_SIZE = 10.megabytes
    MAX_PIXELS = 25_000_000
    MAX_PDF_PAGES = 3
    PREPROCESSING_TIMEOUT = 15
    TARGET_DPI_WIDTH = 2400 # ~300 DPI at 8 inches

    SUPPORTED_MIME = %w[
      image/jpeg image/png image/heic image/heif image/tiff
      application/pdf
    ].freeze

    def initialize(file)
      @file = file
    end

    def call
      validate!
      Timeout.timeout(PREPROCESSING_TIMEOUT) { process }
    rescue Timeout::Error
      raise UnsupportedFormat, I18n.t("ocr.errors.preprocessing_timeout")
    end

    private

    def validate!
      path = file_path
      raise UnsupportedFormat, I18n.t("ocr.errors.file_missing") unless path && File.exist?(path)
      raise UnsupportedFormat, I18n.t("ocr.errors.file_too_large") if File.size(path) > MAX_FILE_SIZE
    end

    def process
      path = file_path

      if pdf?(path)
        process_pdf(path)
      else
        [ process_image(path) ]
      end
    end

    def process_image(path)
      require "vips"

      image = Vips::Image.new_from_file(path, access: :sequential)
      image = image.autorot

      width = image.width
      height = image.height
      raise UnsupportedFormat, I18n.t("ocr.errors.image_too_large") if width * height > MAX_PIXELS

      image = image.colourspace("b-w") if image.bands > 1

      if width > TARGET_DPI_WIDTH
        scale = TARGET_DPI_WIDTH.to_f / width
        image = image.resize(scale)
      end

      output = Tempfile.new([ "ocr_preprocessed", ".tiff" ], binmode: true)
      image.tiffsave(output.path, compression: :none)
      output.path
    end

    def process_pdf(path)
      require "vips"

      pages = pdf_page_count(path)
      raise UnsupportedFormat, I18n.t("ocr.errors.pdf_too_many_pages") if pages > MAX_PDF_PAGES

      (0...pages).map do |page_index|
        image = Vips::Image.pdfload(path, page: page_index, dpi: 300)
        raise UnsupportedFormat, I18n.t("ocr.errors.image_too_large") if image.width * image.height > MAX_PIXELS

        image = image.colourspace("b-w") if image.bands > 1

        output = Tempfile.new([ "ocr_pdf_page_#{page_index}", ".tiff" ], binmode: true)
        image.tiffsave(output.path, compression: :none)
        output.path
      end
    end

    def pdf_page_count(path)
      require "vips"

      image = Vips::Image.pdfload(path, dpi: 72, access: :sequential)
      begin
        image.get("n-pages")
      rescue StandardError
        1
      end.clamp(1, MAX_PDF_PAGES + 1)
    end

    def pdf?(path)
      File.extname(path).downcase == ".pdf" ||
        File.open(path, "rb") { |f| f.read(5) == "%PDF-" }
    end

    def file_path
      if @file.respond_to?(:tempfile)
        @file.tempfile.path
      elsif @file.respond_to?(:path)
        @file.path
      elsif @file.is_a?(String) && File.exist?(@file)
        @file
      end
    end
  end
end
