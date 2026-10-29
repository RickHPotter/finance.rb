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
      raise InvalidDocument, I18n.t("fiscal_import.messages.xml_unreadable")
    end

    private

    def validate_payload!
      raise InvalidDocument, I18n.t("fiscal_import.messages.xml_empty_or_large") if @xml.blank? || @xml.bytesize > MAX_BYTES
      raise InvalidDocument, I18n.t("fiscal_import.messages.xml_doctype_unsupported") if @xml.match?(/<!DOCTYPE|<!ENTITY/i)
    end

    def authorized_info(document)
      info = document.at_xpath("/nfeProc/NFe/infNFe")
      protocol = document.at_xpath("/nfeProc/protNFe/infProt")
      raise InvalidDocument, I18n.t("fiscal_import.messages.authorized_xml_required") unless info && %w[100 150].include?(value_at(protocol, "cStat"))

      key = AccessKey.new(info["Id"].to_s.delete_prefix("NFe"))
      raise InvalidDocument, I18n.t("fiscal_import.messages.access_key_invalid") unless key.valid?
      raise InvalidDocument, I18n.t("fiscal_import.messages.document_model_mismatch") if value_at(info, "ide/mod") != key.model

      protocol_key = value_at(protocol, "chNFe")
      if (key.model == "55" && protocol_key.blank?) || (protocol_key.present? && protocol_key != key.value)
        raise InvalidDocument, I18n.t("fiscal_import.messages.protocol_key_mismatch")
      end

      [ info, key ]
    end

    def build_draft(info, key)
      rows = info.xpath("det")
      raise InvalidDocument, I18n.t("fiscal_import.messages.item_rows_missing") if rows.empty? || rows.size > MAX_ITEMS

      total_cents = cents(value_at(info, "total/ICMSTot/vNF"))
      raise InvalidDocument, I18n.t("fiscal_import.messages.document_total_invalid") unless total_cents.positive?

      details = fiscal_details(info, rows)
      Draft.new(
        access_key: key.value,
        issuer: value_at(info, "emit/xNome"),
        issued_at: Time.zone.parse(value_at(info, "ide/dhEmi") || value_at(info, "ide/dEmi")),
        total_cents:,
        items: rows.map { |row| parse_item(row) },
        source: "xml",
        fiscal_details: details,
        discount_cents: adjustment_cents(details, "vDesc"),
        freight_cents: adjustment_cents(details, "vFrete")
      )
    end

    def adjustment_cents(details, field)
      item_amounts = details[:items].filter_map { |item| item[:amounts][field] }
      document_amount = details[:document_totals][field]
      raise InvalidDocument, I18n.t("fiscal_import.messages.adjustment_mismatch") if document_amount && item_amounts.any? && document_amount != item_amounts.sum

      document_amount || item_amounts.sum
    end

    def fiscal_details(info, rows)
      {
        model: value_at(info, "ide/mod"),
        document_totals: fiscal_amounts(info.at_xpath("total/ICMSTot"), %w[vProd vDesc vFrete vSeg vOutro vNF]),
        items: rows.map { |row| fiscal_item_details(row) }
      }
    end

    def fiscal_item_details(row)
      product = row.at_xpath("prod")
      raise InvalidDocument, I18n.t("fiscal_import.messages.item_data_missing") unless product

      {
        product_code: value_at(product, "cProd"),
        quantity: value_at(product, "qCom"),
        unit: value_at(product, "uCom"),
        unit_price: value_at(product, "vUnCom"),
        amounts: fiscal_amounts(product, %w[vProd vDesc vFrete vSeg vOutro])
      }
    end

    def fiscal_amounts(node, fields)
      fields.each_with_object({}) do |field, result|
        value = value_at(node, field)
        result[field] = cents(value) if value.present?
      end
    end

    def parse_item(row)
      product = row.at_xpath("prod")
      raise InvalidDocument, I18n.t("fiscal_import.messages.item_data_missing") unless product

      description = value_at(product, "xProd")
      amount = cents(value_at(product, "vProd"))
      raise InvalidDocument, I18n.t("fiscal_import.messages.item_data_invalid") if description.blank? || amount.negative?

      { description: description.first(255), price_cents: amount }
    end

    def cents(value)
      raise InvalidDocument, I18n.t("fiscal_import.messages.amount_value_invalid") unless value.to_s.match?(/\A\d+(?:\.\d{1,2})?\z/)

      (BigDecimal(value) * 100).to_i
    end

    def value_at(node, path)
      return if node.nil?

      node.at_xpath(path)&.text&.strip
    end
  end
end
