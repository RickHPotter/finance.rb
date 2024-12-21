# frozen_string_literal: true

module Import
  class FromXls
    attr_reader :file_path, :xlsx, :headers, :hash_collection

    OBLIGATORY_HEADERS = %i[date description category category2 price reference].freeze

    def initialize(file_path)
      @file_path = file_path
      @xlsx = Roo::Spreadsheet.open(@file_path)
      @headers = {}
      @hash_collection = {}
    end

    def import
      @xlsx.sheets.each do |sheet_name|
        next if sheet_name == "PIX"

        Rails.logger.info "STARTING data extraction from sheet: #{sheet_name}"
        import_sheet(@xlsx.sheet(sheet_name), sheet_name)
      end

      # Import::FromHash.new(@hash_collection).import
    end

    private

    def import_sheet(sheet, sheet_name)
      build_headers(sheet.row(1), sheet_name)
      build_hash(sheet, sheet_name)
    end

    def build_headers(row, sheet_name)
      headers = row.map { |header| header&.downcase&.to_sym }
      return if headers.intersection(OBLIGATORY_HEADERS).sort != OBLIGATORY_HEADERS.sort

      @headers[sheet_name] = {}

      headers.each_with_index.map do |header, index|
        next if header.blank? || OBLIGATORY_HEADERS.exclude?(header)

        @headers[sheet_name][index] = header
      end
    end

    def build_hash(sheet, sheet_name)
      return if @headers[sheet_name].blank?
      return if sheet.last_row < 2

      @hash_collection ||= {}
      @hash_collection[sheet_name] = []

      (2..sheet.last_row).each do |row_index|
        row_array = sheet.row(row_index)
        next if row_array.compact_blank.empty?

        attributes = {}
        row_array.each_with_index do |value, index|
          next if OBLIGATORY_HEADERS.none? @headers[sheet_name][index]

          attribute = @headers[sheet_name][index]
          attributes[attribute] = value
        end

        @hash_collection[sheet_name] << attributes.merge!(additional_params(attributes))
      end
    end

    def additional_params(attributes)
      *ct_description, possible_installment = attributes[:description].to_s.split
      ct_description = ct_description.join(" ")
      ref_month_year = RefMonthYear.from_string(attributes[:reference].to_s)

      if ct_description.parameterize.exclude?("titulo") && possible_installment.include?("/")
        installment_id, installments_count = possible_installment.split("/").map(&:to_i)
      else
        ct_description = attributes[:description]
        installment_id = 1
        installments_count = 1
      end

      { ct_description:, installment_id:, installments_count:, ref_month: ref_month_year.month, ref_year: ref_month_year.year }
    end
  end
end
