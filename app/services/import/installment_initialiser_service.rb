# frozen_string_literal: true

module Import
  class InstallmentInitialiserService
    delegate :transactions_collection, to: :@main_service

    def initialize(main_service)
      @main_service = main_service
    end

    def prepare_installments(user_card, transaction_zero)
      user_card_name = user_card.user_card_name
      card_installments_count = transaction_zero[:installments_count]

      indexes = cleanse_indexes(user_card_name, transaction_zero, card_installments_count)

      card_installments = indexes.map do |index|
        installment = transactions_collection[user_card_name][:with_pending_installments][index]

        paid = installment[:date].present? && Date.current >= installment[:date]
        installment.slice(:number, :date, :month, :year, :price).merge(paid:)
      end

      indexes.reverse_each do |index|
        transactions_collection[user_card_name][:with_pending_installments].delete_at(index)
      end

      validate_installments(transaction_zero, card_installments)
    end

    def cleanse_indexes(user_card_name, transaction_zero, card_installments_count)
      indexes = filter_indexes_by_attributes(user_card_name, transaction_zero, card_installments_count)
      indexes = filter_indexes_by_price_similarity(indexes, user_card_name, transaction_zero, card_installments_count) if indexes.count > card_installments_count
      indexes = filter_indexes_by_month_order(indexes, user_card_name, transaction_zero, card_installments_count) if indexes.count != card_installments_count
      indexes
    end

    def filter_indexes_by_attributes(user_card_name, transaction_zero, card_installments_count)
      transactions_collection[user_card_name][:with_pending_installments].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != card_installments_count
        next if transaction[:description] != transaction_zero[:description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:entity] != transaction_zero[:entity]

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, card_installments_count, transaction_zero[:description])
    end

    def filter_indexes_by_price_similarity(indexes, user_card_name, transaction_zero, card_installments_count)
      indexes.map do |index|
        transaction = transactions_collection[user_card_name][:with_pending_installments][index]

        next if transaction[:price] - transaction_zero[:price] <= transaction_zero[:price] * 0.06
        next if transaction[:price] - transaction_zero[:price] >= transaction_zero[:price] * 0.06 * -1

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, card_installments_count, transaction_zero[:description])
    end

    def filter_indexes_by_month_order(indexes, user_card_name, transaction_zero, card_installments_count)
      transaction_zero_date = transaction_zero[:date]
      transaction_zero_reference = Date.new(2000 + transaction_zero[:year], transaction_zero[:month])

      new_indexes = []
      indexes.each do |index|
        installment = transactions_collection[user_card_name][:with_pending_installments][index]
        pos = new_indexes.count

        installment_number = installment[:number]
        installment_date = installment[:date]
        installment_reference = Date.new(2000 + installment[:year], installment[:month])

        next if installment_number != pos + 1
        next if installment_date != transaction_zero_date.next_month(pos)
        next if installment_reference != transaction_zero_reference.next_month(pos)

        new_indexes << index
      end

      validate_installments_count_by_indexes(new_indexes, card_installments_count, transaction_zero[:description])
    end

    def validate_installments_count_by_indexes(indexes, card_installments_count, description)
      return indexes if indexes.count >= card_installments_count

      raise StandardError, "Expected #{card_installments_count} installments, got: #{indexes.count} for #{description}."
    end

    def validate_installments(transaction_zero, card_installments)
      card_installments.sort_by! { |installment| installment[:number] }

      if transaction_zero[:installments_count] != card_installments.count
        raise StandardError, "Unable to decipher these card_installments: #{transaction_zero}\n#{card_installments}"
      end

      card_installments.each_with_index do |installment, index|
        raise StandardError, "Installment no. #{installment[:number]} is not #{index + 1}: #{transaction_zero}\n#{installment}" if installment[:number] != index + 1
      end

      card_installments
    end
  end
end
