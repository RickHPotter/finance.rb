# frozen_string_literal: true

module FiscalReceipts
  class SourceKey
    class InvalidSource < StandardError; end

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
      if %w[http https].include?(uri.scheme) && uri.host == ParanaLookup::HOST && uri.path == ParanaLookup::PATH
        return URI.decode_www_form(uri.query.to_s).to_h.fetch("p").split("|", 2).first
      end
      return @value if uri.scheme == "https" && uri.host == GoiasLookup::HOST && uri.path == GoiasLookup::PATH

      raise InvalidSource, I18n.t("fiscal_import.messages.source_url_invalid")
    rescue URI::InvalidURIError, KeyError
      raise InvalidSource, I18n.t("fiscal_import.messages.source_url_invalid")
    end
  end
end
