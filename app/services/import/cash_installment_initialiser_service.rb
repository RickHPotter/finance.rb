# frozen_string_literal: true

module Import
  class CashInstallmentInitialiserService
    delegate :transactions_collection, to: :@main_service

    def initialize(main_service)
      @main_service = main_service
    end

    def prepare_installments(transaction_zero)
      cash_installments_count = transaction_zero[:installments_count]

      indexes = cleanse_indexes(transaction_zero, cash_installments_count)

      cash_installments = indexes.map do |index|
        installment = transactions_collection[:with_pending_installments][index]

        paid = installment[:date].present? && Date.current >= installment[:date]
        installment.slice(:number, :date, :month, :year, :price).merge(paid:)
      end

      indexes.reverse_each do |index|
        transactions_collection[:with_pending_installments].delete_at(index)
      end

      validate_installments(transaction_zero, cash_installments)
    end

    def cleanse_indexes(transaction_zero, cash_installments_count)
      indexes = filter_indexes_by_attributes(transaction_zero, cash_installments_count)
      indexes = filter_indexes_by_price_similarity(indexes, transaction_zero, cash_installments_count) if indexes.count > cash_installments_count
      indexes = filter_indexes_by_number(indexes, transaction_zero, cash_installments_count) if indexes.count != cash_installments_count
      indexes = filter_indexes_by_reference(indexes, transaction_zero, cash_installments_count) if indexes.count != cash_installments_count
      indexes = filter_indexes_by_month_order(indexes, transaction_zero, cash_installments_count) if indexes.count != cash_installments_count
      indexes
    end

    def filter_indexes_by_attributes(transaction_zero, cash_installments_count)
      transactions_collection[:with_pending_installments].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != cash_installments_count
        next if transaction[:description] != transaction_zero[:description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:entity] != transaction_zero[:entity]

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, cash_installments_count, transaction_zero[:description])
    end

    def filter_indexes_by_price_similarity(indexes, transaction_zero, cash_installments_count)
      indexes.map do |index|
        transaction = transactions_collection[:with_pending_installments][index]

        if transaction[:price] != transaction_zero[:price]
          min_price = [ transaction[:price], transaction_zero[:price] ].min
          max_price = [ transaction[:price], transaction_zero[:price] ].max
          next if (max_price - min_price).abs >= transaction_zero[:price].abs * 0.06
        end

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, cash_installments_count, transaction_zero[:description])
    end

    def filter_indexes_by_number(indexes, transaction_zero, cash_installments_count)
      new_indexes = []
      indexes.each do |index|
        next if transactions_collection[:with_pending_installments][index][:number] != new_indexes.count + 1

        new_indexes << index
      end

      validate_installments_count_by_indexes(new_indexes, cash_installments_count, transaction_zero[:description])
    end

    def filter_indexes_by_reference(indexes, transaction_zero, cash_installments_count)
      transaction_zero_date = transaction_zero[:date]
      transaction_zero_reference = Date.new(2000 + transaction_zero[:year], transaction_zero[:month])

      new_indexes = []
      indexes.each do |index|
        installment = transactions_collection[:with_pending_installments][index]
        pos = new_indexes.count

        installment_date = installment[:date]
        installment_reference = Date.new(2000 + installment[:year], installment[:month])

        next if installment_date != transaction_zero_date.next_month(pos)
        next if installment_reference != transaction_zero_reference.next_month(pos)

        new_indexes << index
      end

      validate_installments_count_by_indexes(new_indexes, cash_installments_count, transaction_zero[:description])
    end

    def filter_indexes_by_month_order(indexes, transaction_zero, cash_installments_count)
      transaction_zero_date = transaction_zero[:date]
      transaction_zero_reference = Date.new(2000 + transaction_zero[:year], transaction_zero[:month])

      new_indexes = []
      indexes.each do |index|
        installment = transactions_collection[:with_pending_installments][index]
        pos = new_indexes.count

        installment_date = installment[:date]
        installment_reference = Date.new(2000 + installment[:year], installment[:month])

        next if installment_date != transaction_zero_date.next_month(pos)
        next if installment_reference != transaction_zero_reference.next_month(pos)

        new_indexes << index
      end

      validate_installments_count_by_indexes(new_indexes, cash_installments_count, transaction_zero[:description])
    end

    def validate_installments_count_by_indexes(indexes, cash_installments_count, description)
      return indexes if indexes.count >= cash_installments_count

      raise StandardError, "Expected #{cash_installments_count} installments, got: #{indexes.count} for #{description}."
    end

    def validate_installments(transaction_zero, cash_installments)
      cash_installments.sort_by! { |installment| installment[:number] }

      if transaction_zero[:installments_count] != cash_installments.count
        raise StandardError, "Unable to decipher these cash_installments: #{transaction_zero}\n#{cash_installments}"
      end

      cash_installments.each_with_index do |installment, index|
        raise StandardError, "Installment no. #{installment[:number]} is not #{index + 1}: #{transaction_zero}\n#{installment}" if installment[:number] != index + 1
      end

      cash_installments
    end
  end
end
