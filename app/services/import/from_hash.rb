# frozen_string_literal: true

module Import
  class FromHash # rubocop:disable Metrics/ClassLength
    attr_reader :hash_collection, :collection, :user, :user_id

    def initialize(hash_collection)
      @hash_collection = hash_collection
      @collection = {}
    end

    def import
      create_user

      @hash_collection.each do |card, transactions|
        user_card = create_user_card(card)
        create_collection(user_card, transactions)
      end

      Rails.logger.info "Date creation finished."
    end

    private

    def create_user
      @user = User.find_or_create_by(first_name: "Rikki", last_name: "Potteru", email: "rikki.potteru@mail.com") do |user|
        user.password = "123123"
        user.confirmed_at = Date.current
      end
      @user_id = @user.id
    end

    def create_user_card(card_name)
      Rails.logger.info "Creating card: #{card_name}."

      bank = Bank.find_or_create_by(bank_name: card_name, bank_code: card_name.upcase)
      card = Card.find_or_create_by(card_name: card_name, bank:)

      UserCard.create(user:, card:, current_due_date: Date.current.end_of_month, days_until_due_date: 7, min_spend: 0, credit_limit: 1000, active: true)
    end

    def create_collection(user_card, transactions)
      Rails.logger.info "Creating data estructure for card: #{user_card.user_card_name}."

      @collection[user_card.user_card_name] = {}

      standalone_transactions, transactions_with_installments = transactions.partition { |trans| trans[:installments_count] == 1 }

      create_standalone_transactions(user_card, standalone_transactions)
      create_transactions_with_installments(user_card, transactions_with_installments)
    end

    def create_standalone_transactions(user_card, standalone_transactions)
      Rails.logger.info "Creating standalone transactions for card: #{user_card.user_card_name}."

      @collection[user_card.user_card_name][:standalone] = standalone_transactions.map do |trans|
        card_transaction = { ct_description: trans[:ct_description], price: trans[:price], date: trans[:date], user_id:, user_card_id: user_card.id }

        Params::CardTransactionParamsService.new(card_transaction:, installments: { count: 1 }, category_transactions: [], entity_transactions: [])
      end
    end

    def create_transactions_with_installments(user_card, transactions_with_installments)
      Rails.logger.info "Creating transactions with installments for card: #{user_card.user_card_name}."

      user_card_name = user_card.user_card_name

      @collection[user_card_name][:with_pending_installments] = transactions_with_installments
      @collection[user_card_name][:with_installments] = []

      while @collection[user_card_name][:with_pending_installments].any?
        transaction_zero = @collection[user_card_name][:with_pending_installments].first

        installments = prepare_installments(user_card, transaction_zero)
        price = installments.pluck(:price).sum

        @collection[user_card_name][:with_installments] << Params::CardTransactionParamsService.new(
          card_transaction: { ct_description: transaction_zero[:ct_description], price:, date: transaction_zero[:date], user_id:, user_card_id: user_card.id },
          installments:,
          category_transactions: [],
          entity_transactions: []
        )
      end
    end

    def prepare_installments(user_card, transaction_zero)
      user_card_name = user_card.user_card_name
      installments_count = transaction_zero[:installments_count]

      indexes = filter_indexes(user_card_name, transaction_zero, installments_count)
      indexes = filter_indexes_again(indexes, user_card_name, transaction_zero, installments_count) if indexes.count > installments_count
      indexes = filter_indexes_once_again(indexes, user_card_name, transaction_zero, installments_count) if indexes.count != installments_count

      installments = indexes.map do |index|
        installment = @collection[user_card_name][:with_pending_installments][index]

        { number: installment[:installment_id], price: installment[:price], month: installment[:ref_month], year: installment[:ref_year], date: installment[:date] }
      end

      indexes.reverse_each do |index|
        @collection[user_card_name][:with_pending_installments].delete_at(index)
      end

      validate_installments(transaction_zero, installments)
    end

    def filter_indexes(user_card_name, transaction_zero, installments_count)
      @collection[user_card_name][:with_pending_installments].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != installments_count
        next if transaction[:ct_description] != transaction_zero[:ct_description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:category2] != transaction_zero[:category2]

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, installments_count, transaction_zero[:ct_description])
    end

    def filter_indexes_again(indexes, user_card_name, transaction_zero, installments_count)
      indexes.map do |index|
        transaction = @collection[user_card_name][:with_pending_installments][index]

        next if transaction[:price] - transaction_zero[:price] <= transaction_zero[:price] * 0.06
        next if transaction[:price] - transaction_zero[:price] >= transaction_zero[:price] * 0.06 * -1

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, installments_count, transaction_zero[:ct_description])
    end

    def filter_indexes_once_again(indexes, user_card_name, transaction_zero, installments_count)
      transaction_zero_date = transaction_zero[:date]
      transaction_zero_reference = Date.new(2000 + transaction_zero[:ref_year], transaction_zero[:ref_month])

      new_indexes = []
      indexes.each do |index|
        installment = @collection[user_card_name][:with_pending_installments][index]
        pos = new_indexes.count
        next_pos = pos + 1

        installment_number = installment[:installment_id]
        installment_date = installment[:date]
        installment_reference = Date.new(2000 + installment[:ref_year], installment[:ref_month])

        next if installment_number != next_pos
        next if installment_date != transaction_zero_date.next_month(pos)
        next if installment_reference != transaction_zero_reference.next_month(pos)

        new_indexes << index
      end

      validate_installments_count_by_indexes(new_indexes, installments_count, transaction_zero[:ct_description])
    end

    def validate_installments_count_by_indexes(indexes, installments_count, ct_description)
      return indexes if indexes.count >= installments_count

      raise StandardError, "Expected #{installments_count} installments, got: #{indexes.count} for #{ct_description}."
    end

    def validate_installments(transaction_zero, installments)
      installments.sort_by! { |installment| installment[:number] }

      if transaction_zero[:installments_count] != installments.count
        raise StandardError, "Unable to decipher these installments: #{transaction_zero}\n#{installments}"
      end

      installments.each_with_index do |installment, index|
        raise StandardError, "Installment no. #{installment[:number]} is not #{index + 1}: #{transaction_zero}\n#{installment}" if installment[:number] != index + 1
      end

      installments
    end
  end
end

=begin # rubocop:disable all
xlsx_service = Import::FromXls.new(File.open(File.join("/mnt", "c", "Users", "Administrator", "Downloads", "finance.xlsx")))
xlsx_service.import
hash_service = Import::FromHash.new(xlsx_service.hash_collection)
hash_service.import
=end
