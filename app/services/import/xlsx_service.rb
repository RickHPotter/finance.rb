# frozen_string_literal: true

module Import
  class XlsxService
    attr_reader :file_path, :xlsx, :headers, :hash_collection

    delegate :log_with, to: LoggerService

    OBLIGATORY_HEADERS = %i[description category entity price reference].freeze
    OPTIONAL_HEADERS = %i[date bank].freeze
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
        @xlsx.sheets.each do |sheet_name|
          next if sheet_name.include? "SKIP"

          import_sheet(@xlsx.sheet(sheet_name), sheet_name)
        end
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
      headers = row.map { |header| header.to_s.downcase&.to_sym }
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
          attributes[header] = row_array[index] if row_array[index].present?
        end

        next if attributes.empty?
        next if attributes.slice(:category, :entity).values == %w[PAYMENT CARD]
        next if attributes[:price].to_d.zero?

        parse_attributes(attributes)
      end.compact
    end

    def parse_attributes(attributes)
      *possible_description, possible_installment = attributes[:description].to_s.split

      attributes.merge!(parse_category_and_entity(attributes))
                .merge!(parse_month_year(attributes))
                .merge!(description: attributes[:description],
                        number: 1,
                        installments_count: 1,
                        price: (attributes[:price].round(2).to_d * 100).to_i)

      return attributes if possible_description.empty?
      return attributes if not_standalone?(possible_description, possible_installment)

      attributes[:description] = possible_description.join(" ")
      attributes[:number], attributes[:installments_count] = possible_installment.split("/").map(&:to_i)

      attributes
    end

    def parse_category_and_entity(attributes)
      case attributes[:category]
      in String then attributes[:category]&.split(",")
      in Array  then attributes[:category]
      else []
      end => category

      case attributes[:entity]
      in String then attributes[:entity]&.split(",")
      in Array  then attributes[:entity]
      else []
      end => entity

      is_payer = false

      category.each_with_index do |cat, index|
        category[index] = "CARD #{cat}" if cat.in?(%w[PAYMENT ADVANCE INSTALLMENT DISCOUNT REVERSAL])
        next if cat != "EXCHANGE" || entity == "MOI"

        is_payer = true
      end

      { category:, entity:, is_payer: }
    end

    def parse_month_year(attributes)
      ref_month_year = RefMonthYear.from_string(attributes[:reference].to_s)

      if attributes[:date].present?
        attributes[:paid] = Time.zone.today >= attributes[:date]
      else
        attributes[:paid] = false
        attributes[:date] = Date.new(ref_month_year.year, ref_month_year.month, 1).end_of_month
      end

      { month: ref_month_year.month, year: ref_month_year.year, date: attributes[:date] }
    end

    def not_standalone?(description, installments)
      bill_or_subscription = SKIPPABLE_INSTALLMENT_DESCRIPTIONS.include?(description.first.parameterize)
      consists_of_two_installment_parts = installments.split("/").count != 2
      both_are_numbers = installments.split("/") != installments.split("/").map(&:to_i).map(&:to_s)

      bill_or_subscription || consists_of_two_installment_parts || both_are_numbers
    end
  end
end
