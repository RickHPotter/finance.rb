# frozen_string_literal: true

require "net/http"

module FiscalReceipts
  class ParanaLookup
    class Unavailable < StandardError; end

    HOST = "www.fazenda.pr.gov.br"
    PATH = "/nfce/qrcode"
    MAX_RESPONSE_BYTES = 1.megabyte

    def initialize(access_key)
      @access_key = AccessKey.new(access_key)
    end

    def call
      raise Unavailable, I18n.t("fiscal_import.messages.pr_key_invalid") unless @access_key.valid? && @access_key.model == "65"
      raise Unavailable, I18n.t("fiscal_import.messages.pr_only") unless @access_key.state_code == "41"

      response = fetch
      parse(response)
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise Unavailable, I18n.t("fiscal_import.messages.consultation_unavailable")
    end

    private

    def fetch
      query = URI.encode_www_form(p: "#{@access_key.value}|3|1")
      request = Net::HTTP::Get.new("#{PATH}?#{query}")
      request["Accept"] = "text/html"
      body = +""

      Net::HTTP.start(HOST, 443, use_ssl: true, open_timeout: 4, read_timeout: 8) do |http|
        http.request(request) do |response|
          raise Unavailable, I18n.t("fiscal_import.messages.receipt_not_returned") unless response.is_a?(Net::HTTPSuccess)

          response.read_body do |chunk|
            body << chunk
            raise Unavailable, I18n.t("fiscal_import.messages.response_too_large") if body.bytesize > MAX_RESPONSE_BYTES
          end
        end
      end

      body
    end

    def parse(html)
      document = Nokogiri::HTML(html, nil, "UTF-8")
      rows = document.css("#tabResult tr")
      payable_row = document.css("#linhaTotal").find { |row| row.at_css("label")&.text&.include?("Valor a pagar") }
      total = payable_row&.at_css(".totalNumb")&.text
      raise Unavailable, I18n.t("fiscal_import.messages.pr_item_details_missing") if rows.empty? || total.blank?
      raise Unavailable, I18n.t("fiscal_import.messages.too_many_items") if rows.size > 500

      items = rows.map { |row| parse_item(row) }
      Draft.new(
        access_key: @access_key.value,
        issuer: document.at_css("#u20")&.text&.strip,
        issued_at: issue_time(document.text),
        total_cents: brazilian_cents(total),
        items:,
        source: "sefaz_pr"
      )
    end

    def parse_item(row)
      description = row.at_css(".txtTit2")&.text&.strip
      amount_text = row.at_css("td.txtTit3")&.text
      amount = amount_text&.match(/\d[\d.]*,\d{2}/)&.to_s
      raise Unavailable, I18n.t("fiscal_import.messages.item_unreadable") if description.blank? || amount.blank?

      { description: description.first(255), price_cents: brazilian_cents(amount) }
    end

    def brazilian_cents(value)
      normalized = value.to_s.strip
      raise Unavailable, I18n.t("fiscal_import.messages.amount_invalid") unless normalized.match?(/\A\d[\d.]*,\d{2}\z/)

      (BigDecimal(normalized.delete(".").tr(",", ".")) * 100).to_i
    end

    def issue_time(text)
      value = text.match(%r{Emiss[aã]o:\s*(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})}i)&.captures&.first
      Time.zone.strptime(value, "%d/%m/%Y %H:%M:%S") if value
    end
  end
end
