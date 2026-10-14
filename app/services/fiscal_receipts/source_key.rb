# frozen_string_literal: true

module FiscalReceipts
  class SourceKey
    class InvalidSource < StandardError; end

    HOST = FiscalReceipts::ParanaLookup::HOST
    PATH = FiscalReceipts::ParanaLookup::PATH

    def initialize(value)
      @value = value.to_s.strip
    end

    def call
      return @value.delete(" ") if @value.match?(/\A[\d\s]+\z/)

      url_key
    end

    private

    def url_key
      uri = URI.parse(@value)
      raise InvalidSource, "Use a Paraná NFC-e QR URL or a 44-digit access key." unless %w[http https].include?(uri.scheme) && uri.host == HOST && uri.path == PATH

      URI.decode_www_form(uri.query.to_s).to_h.fetch("p").split("|", 2).first
    rescue URI::InvalidURIError, KeyError
      raise InvalidSource, "Use a Paraná NFC-e QR URL or a 44-digit access key."
    end
  end
end
