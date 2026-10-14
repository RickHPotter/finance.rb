# frozen_string_literal: true

module FiscalReceipts
  class XmlParser
    class InvalidDocument < StandardError; end

    MAX_BYTES = 10.megabytes
    MAX_ITEMS = 500

    def initialize(xml)
      @xml = xml.to_s
    end

    def call
      validate_payload!
      document = Nokogiri::XML(@xml) { |config| config.strict.nonet }
      document.remove_namespaces!
      info, key = authorized_info(document)
      build_draft(info, key)
    rescue Nokogiri::XML::SyntaxError, ArgumentError, TypeError
      raise InvalidDocument, "The fiscal XML could not be read."
    end

    private

    def validate_payload!
      raise InvalidDocument, "The XML is empty or too large." if @xml.blank? || @xml.bytesize > MAX_BYTES
      raise InvalidDocument, "Document type declarations are not supported." if @xml.match?(/<!DOCTYPE|<!ENTITY/i)
    end

    def authorized_info(document)
      info = document.at_xpath("/nfeProc/NFe/infNFe")
      protocol = document.at_xpath("/nfeProc/protNFe/infProt/cStat")&.text
      raise InvalidDocument, "An authorized NF-e or NFC-e XML is required." unless info && %w[100 150].include?(protocol)

      key = AccessKey.new(info["Id"].to_s.delete_prefix("NFe"))
      raise InvalidDocument, "The fiscal access key is invalid." unless key.valid?
      raise InvalidDocument, "The fiscal document model does not match its key." unless value_at(info, "ide/mod") == key.model

      [ info, key ]
    end

    def build_draft(info, key)
      rows = info.xpath("det")
      raise InvalidDocument, "The fiscal document has no supported item rows." if rows.empty? || rows.size > MAX_ITEMS

      total_cents = cents(value_at(info, "total/ICMSTot/vNF"))
      raise InvalidDocument, "The fiscal document total is invalid." unless total_cents.positive?

      Draft.new(
        access_key: key.value,
        issuer: value_at(info, "emit/xNome"),
        issued_at: Time.zone.parse(value_at(info, "ide/dhEmi") || value_at(info, "ide/dEmi")),
        total_cents:,
        items: rows.map { |row| parse_item(row) },
        source: "xml"
      )
    end

    def parse_item(row)
      product = row.at_xpath("prod")
      raise InvalidDocument, "A fiscal item is missing its description or amount." unless product

      description = value_at(product, "xProd")
      amount = cents(value_at(product, "vProd")) - optional_cents(product, "vDesc") +
               optional_cents(product, "vFrete") + optional_cents(product, "vSeg") + optional_cents(product, "vOutro")
      raise InvalidDocument, "A fiscal item has an invalid description or amount." if description.blank? || !amount.positive?

      { description: description.first(255), price_cents: amount }
    end

    def optional_cents(node, path)
      value = value_at(node, path)
      value.present? ? cents(value) : 0
    end

    def cents(value)
      raise InvalidDocument, "A fiscal amount is invalid." unless value.to_s.match?(/\A\d+(?:\.\d{1,2})?\z/)

      (BigDecimal(value) * 100).to_i
    end

    def value_at(node, path)
      node.at_xpath(path)&.text&.strip
    end
  end
end
