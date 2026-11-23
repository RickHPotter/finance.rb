# frozen_string_literal: true

module Ocr
  class ReceiptParser
    CONFIDENCE_HIGH = 85
    CONFIDENCE_MEDIUM = 60

    # Matches: "1 ARROZ TIPO 1 5KG 1 24,90 24,90" or "ARROZ TIPO 1 5KG 24,90"
    ITEM_PATTERN = /\A\s*(\d+\s+)?(.+?)\s+(\d+)\s+(\d{1,3}(?:[.,]\d{2})?)\s+(\d{1,6}(?:[.,]\d{2})?)\s*\z/
    # Simpler: "DESCRIPTION PRICE" at end of line
    SIMPLE_ITEM_PATTERN = /\A\s*(\d+\s+)?(.+?)\s+(\d{1,6}(?:[.,]\d{2}))\s*\z/

    TOTAL_PATTERN = /\b(?:TOTAL|VALOR\s*TOTAL)\b.*?(\d{1,3}(?:\.\d{3})*,\d{2})/i
    DATE_PATTERN = %r{(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2}(?::\d{2})?)}
    ACCESS_KEY_PATTERN = /(?:\d\s*){44}/
    ISSUER_STOP_WORDS = %w[CNPJ CPF CUPOM FISCAL DATA TOTAL CHAVE].freeze

    def initialize(ocr_output)
      @ocr_output = ocr_output
      @lines = ocr_output[:lines] || []
    end

    def call
      items = extract_items
      total = extract_total
      issuer = extract_issuer
      issued_at = extract_date
      access_key = extract_access_key

      field_confidences = build_field_confidences(
        items: items, total: total, issuer: issuer,
        issued_at: issued_at, access_key: access_key
      )

      ReceiptDraft.new(
        issuer: issuer,
        issued_at: issued_at,
        total_cents: total,
        items: items,
        access_key: access_key,
        field_confidences: field_confidences,
        source_engine: @ocr_output[:engine],
        processing_ms: @ocr_output[:processing_ms]
      )
    end

    private

    def extract_items
      items = []
      item_zone = false

      @lines.each do |line|
        text = line[:text].to_s.strip
        item_zone = true if item_zone_header?(text)
        next if item_zone_header?(text)
        break if total_or_payment_section?(text)

        item = parse_item_line(text, line[:confidence] || 0, in_item_zone: item_zone)
        items << item if item
      end

      items
    end

    def item_zone_header?(text)
      text.match?(/\bDESCRICAO\b/i) || text.match?(/\bQTD\b.*\bVL/i)
    end

    def total_or_payment_section?(text)
      text.match?(/\b(?:VALOR\s+)?TOTAL\b/i) || text.match?(/\A\s*(?:DINHEIRO|CARTAO|CREDITO|DEBITO|PIX)\b/i)
    end

    def parse_item_line(text, confidence, in_item_zone:)
      if (match = text.match(ITEM_PATTERN))
        return build_item(match[2], parse_price(match[5]), confidence)
      end

      if (match = text.match(SIMPLE_ITEM_PATTERN))
        return build_item(match[2], parse_price(match[3]), confidence)
      end

      parse_loose_item_line(text, confidence) if in_item_zone
    end

    def parse_loose_item_line(text, confidence)
      return unless text.match?(/\d{1,6}[.,]\d{2}\s*\z/) && text.length > 5

      price_match = text.match(/(\d{1,6}[.,]\d{2})\s*\z/)
      description = text.sub(/\s*\d+\s*\d{1,6}[.,]\d{2}\s*\z/, "").sub(/\A\d+\s+/, "").strip
      build_item(description, parse_price(price_match[1]), confidence) if description.present? && price_match
    end

    def extract_total
      @lines.each do |line|
        text = line[:text].to_s
        next unless (match = text.match(TOTAL_PATTERN))

        return parse_price(match[1])
      end

      nil
    end

    def extract_issuer
      # Issuer is typically in the first few lines before CNPJ/fiscal headers
      @lines.first(5).each do |line|
        text = line[:text].to_s.strip
        next if text.blank? || text.length < 3
        next if text.match?(/\A[=\-*#\s]+\z/) # Decorative lines
        next if ISSUER_STOP_WORDS.any? { |word| text.start_with?(word) }
        next if text.match?(/\A\d/) # Starts with digit (address number, item, etc.)
        next if text.match?(/\A[#*]/) # Comment-like lines

        return text.first(255)
      end

      nil
    end

    def extract_date
      @lines.each do |line|
        text = line[:text].to_s
        next unless (match = text.match(DATE_PATTERN))

        date_str = "#{match[1]} #{match[2]}"
        begin
          return Time.zone.strptime(date_str, "%d/%m/%Y %H:%M:%S")
        rescue ArgumentError
          begin
            return Time.zone.strptime(date_str, "%d/%m/%Y %H:%M")
          rescue ArgumentError
            next
          end
        end
      end

      nil
    end

    def extract_access_key
      full_text = @lines.map { |l| l[:text] }.join(" ")
      candidates = full_text.scan(ACCESS_KEY_PATTERN).map { |c| c.gsub(/\D/, "") }
      candidates.find { |c| FiscalReceipts::AccessKey.new(c).valid? }
    end

    def build_item(description, price_cents, confidence)
      conf_level = confidence_level(confidence)
      {
        description: description.first(255),
        price_cents: price_cents,
        confidence: conf_level,
        ocr_original: { description: description.first(255), price_cents: price_cents }
      }
    end

    def parse_price(price_str)
      # Brazilian format: 1.234,56 or 1234,56
      normalized = price_str.to_s.gsub(".", "").tr(",", ".")
      (BigDecimal(normalized) * 100).to_i
    rescue ArgumentError, TypeError
      0
    end

    def confidence_level(value)
      if value >= CONFIDENCE_HIGH
        :high
      elsif value >= CONFIDENCE_MEDIUM
        :medium
      else
        :low
      end
    end

    def build_field_confidences(items:, total:, issuer:, issued_at:, access_key:)
      result = {}

      if items.present?
        avg_item_conf = items.filter_map { |i| { high: 95, medium: 75, low: 40 }[i[:confidence]] }.then { |vals| vals.any? ? vals.sum / vals.size : 0 }
        result[:items] = confidence_level(avg_item_conf)
      else
        result[:items] = :low
        result[:items_missing] = true
      end

      result[:total] = total ? :high : :low
      result[:issuer] = issuer ? :medium : :low
      result[:issued_at] = issued_at ? :high : :low
      result[:access_key] = access_key ? :medium : :low

      result
    end
  end
end
