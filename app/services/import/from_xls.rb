# frozen_string_literal: true

module Import
  class FromXls
    attr_reader :file_path, :xlsx, :headers, :hash_collection

    OBLIGATORY_HEADERS = %i[date description category entity price reference].freeze
    SKIPPABLE_INSTALLMENT_DESCRIPTIONS = %w[plano titulo estorno].freeze

    def initialize(file_path)
      @file_path = file_path
      @xlsx = Roo::Spreadsheet.open(@file_path)
      @headers = {}
      @hash_collection = {}
    end

    def import
      Rails.logger.info "[START]".blue

      @xlsx.sheets.each do |sheet_name|
        next if sheet_name.include? "PIX"

        import_sheet(@xlsx.sheet(sheet_name), sheet_name)
      end

      Rails.logger.info "[ENDED]".green

      # Import::FromHash.new(@hash_collection).import
    end

    private

    def import_sheet(sheet, sheet_name)
      Rails.logger.info "[START] DATA EXTRACTION #{sheet_name}.".blue

      build_headers(sheet.row(1), sheet_name)
      build_hash(sheet, sheet_name)

      Rails.logger.info "[ENDED] DATA EXTRACTION #{sheet_name}.".green
    end

    def build_headers(row, sheet_name)
      headers = row.map { |header| header.to_s&.downcase&.to_sym }
      return if headers.intersection(OBLIGATORY_HEADERS).sort != OBLIGATORY_HEADERS.sort

      @headers[sheet_name] = {}

      headers.each_with_index.map do |header, index|
        next if header.blank? || OBLIGATORY_HEADERS.exclude?(header)

        @headers[sheet_name][index] = header
      end
    end

    def build_hash(sheet, sheet_name)
      return if @headers[sheet_name].blank?

      @hash_collection[sheet_name] = (2..sheet.last_row).map do |row_index|
        row_array = sheet.row(row_index)
        attributes = {}

        @headers[sheet_name].each do |index, header|
          next if OBLIGATORY_HEADERS.exclude? header

          attributes[header] = row_array[index]
        end

        parse_attributes(attributes.compact_blank)
      end.compact
    end

    def parse_attributes(attributes)
      return nil if attributes.empty?
      return nil if attributes.slice(:description, :entity, :category).values == [ "PAGAMENTO FATURA", "PAYMENT", "CARD" ]

      *possible_description, possible_installment = attributes[:description].to_s.split

      attributes.merge!(parse_category_and_entity(attributes))
                .merge!(parse_month_year(attributes))
                .merge!({ ct_description: attributes[:description],
                          installment_id: 1,
                          installments_count: 1,
                          price: (attributes[:price].to_d * 100).to_i })

      return attributes if possible_description.empty?
      return attributes if not_standalone?(possible_description, possible_installment)

      attributes[:ct_description] = possible_description.join(" ")
      attributes[:installment_id], attributes[:installments_count] = possible_installment.split("/").map(&:to_i)

      attributes
    end

    def parse_category_and_entity(attributes)
      category = attributes[:category]
      entity = attributes[:entity]
      is_payer = false

      category, entity, is_payer = entity, category, true if entity == "EXCHANGE"

      category, entity = entity, category if category == "CARD" && entity.in?(%w[PAYMENT ADVANCE ESTORNO DESCONTO])

      category = "DISCOUNT" if category == "DESCONTO"
      category = "REVERSAL" if category == "ESTORNO"
      category = "DISCOUNT" if category == "DESCONTO"
      category = "BET"      if category == "APOSTA"
      category = "FEES"     if category == "IOF / TAXA"

      is_payer = false if entity == "MOI"

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
