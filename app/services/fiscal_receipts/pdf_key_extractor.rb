# frozen_string_literal: true

require "open3"
require "timeout"

module FiscalReceipts
  class PdfKeyExtractor
    class Unreadable < StandardError; end

    MAX_TEXT_BYTES = 512.kilobytes

    def initialize(file)
      @file = file
    end

    def call
      output, _error, status = Timeout.timeout(10) do
        Open3.capture3("pdftotext", "-f", "1", "-l", "3", "-enc", "UTF-8", @file.tempfile.path, "-")
      end
      raise Unreadable, "The PDF text could not be read." unless status.success? && output.bytesize <= MAX_TEXT_BYTES

      self.class.source_from_text(output)
    rescue Errno::ENOENT, Timeout::Error
      raise Unreadable, "PDF extraction is unavailable right now. Try XML or enter the access key."
    end

    def self.key_from_text(text)
      candidates = text.scan(/(?:\d\s*){44}/).map { |candidate| candidate.gsub(/\D/, "") }
      key = candidates.find { |candidate| AccessKey.new(candidate).valid? }
      raise Unreadable, "No valid 44-digit fiscal access key was found in the PDF." unless key

      key
    end

    def self.source_from_text(text)
      normalized = text.gsub(/\s+/, "")
      qr_url = normalized.match(%r{https://#{Regexp.escape(GoiasLookup::HOST)}#{Regexp.escape(GoiasLookup::PATH)}\?p=\d{44}\|[\d|A-Fa-f]{1,180}})&.to_s
      return qr_url if qr_url.present?

      key_from_text(text)
    end
  end
end
