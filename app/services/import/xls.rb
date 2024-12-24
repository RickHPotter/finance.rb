# frozen_string_literal: true

module Import
  class Xls
    attr_reader :file_path, :xlsx, :headers, :hash_collection

    delegate :log_with, to: LoggerService

    OBLIGATORY_HEADERS = %i[date description category entity price reference].freeze
    OPTIONAL_HEADERS = %i[bank].freeze
    HEADERS = OBLIGATORY_HEADERS + OPTIONAL_HEADERS
    SKIPPABLE_INSTALLMENT_DESCRIPTIONS = %w[plano titulo estorno].freeze

    def initialize(file_path)
      @file_path = file_path
      @xlsx = Roo::Spreadsheet.open(@file_path)
      @headers = {}
      @hash_collection = {}
    end

    def import
      log_with do
        # @xlsx.sheets.each do |sheet_name|
        #   next if sheet_name.include? "SKIP"
        #
        #   import_sheet(@xlsx.sheet(sheet_name), sheet_name)
        # end

        import_sheet(@xlsx.sheet("PIX"), "PIX")
      end
    end

    private

    def import_sheet(sheet, sheet_name)
      log_with("DATA EXTRACTION #{sheet_name}.") do
        build_headers(sheet.row(1), sheet_name)
        build_hash(sheet, sheet_name)
      end
    end

    def build_headers(row, sheet_name)
      headers = row.map { |header| header.to_s&.downcase&.to_sym }
      return if headers.intersection(HEADERS).count < OBLIGATORY_HEADERS.count

      @headers[sheet_name] = {}

      headers.each_with_index.map do |header, index|
        next if header.blank? || HEADERS.exclude?(header)

        @headers[sheet_name][index] = header
      end
    end

    def build_hash(sheet, sheet_name)
      return if @headers[sheet_name].blank?

      @hash_collection[sheet_name] = (2..sheet.last_row).map do |row_index|
        row_array = sheet.row(row_index)
        attributes = {}

        @headers[sheet_name].each do |index, header|
          # next if OBLIGATORY_HEADERS.exclude?(header)
          attributes[header] = row_array[index]
        end

        parse_attributes(attributes.compact_blank)
      end.compact
    end

    def parse_attributes(attributes)
      return nil if attributes.empty?

      *possible_description, possible_installment = attributes[:description].to_s.split

      attributes.merge!(parse_category_and_entity(attributes))
                .merge!(parse_month_year(attributes))
                .merge!({ ct_description: attributes[:description],
                          installment_id: 1,
                          installments_count: 1,
                          price: (attributes[:price].round(2).to_d * 100).to_i })

      return attributes if possible_description.empty?
      return attributes if not_standalone?(possible_description, possible_installment)

      attributes[:ct_description] = possible_description.join(" ")
      attributes[:installment_id], attributes[:installments_count] = possible_installment.split("/").map(&:to_i)

      attributes
    end

    def parse_category_and_entity(attributes)
      category = attributes[:category]
      entity = attributes[:entity]
      is_payer = category == "EXCHANGE" && entity != "MOI"

      { category:, entity:, is_payer: }
    end

    def parse_month_year(attributes)
      ref_month_year = RefMonthYear.from_string(attributes[:reference].to_s)

      { month: ref_month_year.month, year: ref_month_year.year }
    end

    def not_standalone?(description, installments)
      bill_or_subscription = SKIPPABLE_INSTALLMENT_DESCRIPTIONS.include?(description.first.parameterize)
      consists_of_two_installment_parts = installments.split("/").count != 2
      both_are_numbers = installments.split("/") != installments.split("/").map(&:to_i).map(&:to_s)

      bill_or_subscription || consists_of_two_installment_parts || both_are_numbers
    end
  end
end
