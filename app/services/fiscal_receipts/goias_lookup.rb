# frozen_string_literal: true

require "net/http"

module FiscalReceipts
  class GoiasLookup
    class Unavailable < StandardError; end

    HOST = "nfeweb.sefaz.go.gov.br"
    PATH = "/nfeweb/sites/nfce/danfeNFCe"
    DETAIL_PATH = "/nfeweb/sites/nfce/render/danfeNFCe"
    MAX_RESPONSE_BYTES = 1.megabyte

    def initialize(url)
      @url = URI.parse(url)
      @payload = URI.decode_www_form(@url.query.to_s).to_h["p"]
      @access_key = AccessKey.new(@payload.to_s.split("|", 2).first)
    rescue URI::InvalidURIError, ArgumentError
      raise Unavailable, "Enter an official Goiás NFC-e QR URL. A bare GO key cannot bypass the public consultation challenge."
    end

    def call
      validate_source!
      Net::HTTP.start(HOST, 443, use_ssl: true, open_timeout: 4, read_timeout: 8) do |http|
        landing, cookies = fetch(http, "#{PATH}?#{URI.encode_www_form(p: @payload)}")
        raise Unavailable, "The Goiás QR consultation rejected this receipt. Check the complete QR URL." unless valid_landing?(landing)

        detail, = fetch(http, "#{DETAIL_PATH}?#{URI.encode_www_form(chNFe: @access_key.value)}", cookies:)
        parse(detail)
      end
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise Unavailable, "The Goiás fiscal consultation is unavailable right now. Try an XML file or enter the items manually."
    end

    private

    def validate_source!
      valid_uri = @url.scheme == "https" && @url.host == HOST && @url.port == 443 && @url.path == PATH && @url.userinfo.nil? && @url.fragment.nil?
      valid_payload = @payload&.match?(/\A\d{44}\|[\d|A-Fa-f]{1,180}\z/)
      return if valid_uri && valid_payload && @access_key.valid? && @access_key.state_code == "52" && @access_key.model == "65"

      raise Unavailable, "Enter an official Goiás NFC-e QR URL. A bare GO key cannot bypass the public consultation challenge."
    end

    def fetch(http, path, cookies: nil)
      request = Net::HTTP::Get.new(path)
      request["Accept"] = "text/html"
      request["Cookie"] = cookies if cookies.present?
      body = +""
      response_cookies = nil

      http.request(request) do |response|
        raise Unavailable, "The Goiás fiscal consultation did not return a receipt." unless response.is_a?(Net::HTTPSuccess)

        response_cookies = response.get_fields("Set-Cookie")&.map { |cookie| cookie.split(";", 2).first }&.join("; ")
        response.read_body do |chunk|
          body << chunk
          raise Unavailable, "The Goiás fiscal response is too large." if body.bytesize > MAX_RESPONSE_BYTES
        end
      end

      [ body, response_cookies ]
    end

    def valid_landing?(html)
      document = Nokogiri::HTML(html, nil, "ISO-8859-1")
      document.at_css("iframe.iframe-danfe-nfce")&.[]("src") == "#{DETAIL_PATH}?chNFe=#{@access_key.value}"
    end

    def parse(html)
      document = Nokogiri::HTML(extract_receipt_html(html), nil, "UTF-8")
      displayed_key = document.at_css(".chave")&.text&.gsub(/\D/, "")
      raise Unavailable, "The Goiás consultation returned a different receipt. Try an XML file." unless displayed_key == @access_key.value

      rows = document.css("#tabResult tr")
      total = payable_total(document)
      raise Unavailable, "The Goiás consultation did not provide item details. Try an XML file." if rows.empty? || total.blank?
      raise Unavailable, "The fiscal receipt contains too many items to import." if rows.size > 500

      Draft.new(
        access_key: @access_key.value,
        issuer: document.at_css("#u20")&.text&.strip,
        issued_at: issue_time(document.text),
        total_cents: brazilian_cents(total),
        items: rows.map { |row| parse_item(row) },
        source: "sefaz_go"
      )
    end

    def extract_receipt_html(html)
      embedded = html.match(/new DanfeNFCe\(\s*'[^']*',\s*'[^']*',\s*'((?:\\.|[^'\\])*)'\s*\)/m)&.captures&.first
      raise Unavailable, "The Goiás consultation did not provide item details. Try an XML file." if embedded.blank?

      JSON.parse(%["#{embedded.gsub("\\'", "'")}"])
    rescue JSON::ParserError
      raise Unavailable, "The Goiás consultation returned an unreadable receipt. Try an XML file."
    end

    def payable_total(document)
      row = document.css("#linhaTotal").find { |entry| entry.at_css("label")&.text&.include?("Valor a pagar") }
      row&.at_css(".totalNumb")&.text
    end

    def parse_item(row)
      description = row.at_css(".txtTit")&.text&.strip
      amount = row.at_css("td .valor")&.text&.strip
      raise Unavailable, "The Goiás consultation returned an unreadable item." if description.blank? || amount.blank?

      { description: description.first(255), price_cents: brazilian_cents(amount) }
    end

    def brazilian_cents(value)
      normalized = value.to_s.strip
      raise Unavailable, "The Goiás consultation returned an invalid amount." unless normalized.match?(/\A\d[\d.]*,\d{2}\z/)

      (BigDecimal(normalized.delete(".").tr(",", ".")) * 100).to_i
    end

    def issue_time(text)
      value = text.match(%r{Emiss[aã]o:\s*(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})}i)&.captures&.first
      Time.zone.strptime(value, "%d/%m/%Y %H:%M:%S") if value
    end
  end
end
