# frozen_string_literal: true

module FiscalReceipts
  class GoiasDetailSnapshot
    class Unreadable < StandardError; end

    def initialize(html, access_key:)
      @html = html
      @access_key = access_key
    end

    def call
      markup = rendered_markup
      raise Unreadable unless markup.include?(@access_key)

      document = Nokogiri::HTML(markup)
      tables = document.css("table").filter_map { |table| table_data(table) }
      raise Unreadable if tables.empty?

      {
        format: "goias-nfce-detailed-page-v1",
        access_key: @access_key,
        source: "sefaz_go_public_consultation",
        note: "Derived from the public detailed HTML page; not the signed fiscal XML.",
        tables:,
        text: normalize_text(document.text)
      }
    rescue JSON::ParserError
      raise Unreadable
    end

    def rendered_markup
      embedded = @html.match(/new XmlNFE\(\s*'[^']*',\s*'[^']*',\s*'((?:\\.|[^'\\])*)'\s*\)/m)&.captures&.first
      raise Unreadable unless embedded

      JSON.parse(%["#{embedded.gsub("\\'", "'")}"])
    end

    private

    def table_data(table)
      rows = table.css("tr").filter_map do |row|
        cells = row.css("th, td").map { |cell| cell_data(cell) }
        cells if cells.any?(&:present?)
      end
      return if rows.empty?

      section = table.ancestors("fieldset").first&.at_css("legend")&.text
      { section: normalize_text(section), rows: }
    end

    def cell_data(cell)
      text = normalize_text(cell.text)
      label = normalize_text(cell.at_css("label")&.text)
      return text if label.blank?

      { label:, value: text.delete_prefix(label).strip }
    end

    def normalize_text(text)
      text.to_s.gsub(/\s+/, " ").strip
    end
  end
end
