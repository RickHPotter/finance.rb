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
      create_data
      create_transactions
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
      bank = Bank.find_or_create_by(bank_name: card_name, bank_code: card_name.upcase)
      card = Card.find_or_create_by(card_name: card_name, bank:)

      UserCard.find_or_create_by(user:, card:, min_spend: 0, credit_limit: 1000, active: true) do |user_card|
        user_card.current_due_date = Date.current.end_of_month
        user_card.days_until_due_date = 7
      end
    end

    def create_data
      @hash_collection.each do |card, transactions|
        Rails.logger.info "[START] DATA CREATION #{card}.".blue

        user_card = create_user_card(card)
        create_collection(user_card, transactions)

        Rails.logger.info "[ENDED] DATA CREATION #{card}.".green
      end
    end

    def create_collection(user_card, transactions)
      @collection[user_card.user_card_name] = {}

      standalone_transactions, transactions_with_installments = transactions.partition { |trans| trans[:installments_count] == 1 }

      create_standalone_transactions(user_card, standalone_transactions)
      create_transactions_with_installments(user_card, transactions_with_installments)
    end

    def create_standalone_transactions(user_card, standalone_transactions)
      @collection[user_card.user_card_name][:standalone] = standalone_transactions.map do |trans|
        card_transaction = { ct_description: trans[:ct_description], price: trans[:price], date: trans[:date], user_id:, user_card_id: user_card.id }

        category_transactions, entity_transactions = create_category_and_entity_transactions(trans)

        Params::CardTransactionParamsService.new(card_transaction:, installments: { count: 1 }, category_transactions:, entity_transactions:)
      end
    end

    def create_transactions_with_installments(user_card, transactions_with_installments)
      user_card_name = user_card.user_card_name

      @collection[user_card_name][:with_pending_installments] = transactions_with_installments
      @collection[user_card_name][:with_installments] = []

      while @collection[user_card_name][:with_pending_installments].any?
        transaction_zero = @collection[user_card_name][:with_pending_installments].first

        installments = prepare_installments(user_card, transaction_zero)
        price = installments.pluck(:price).sum
        category_transactions, entity_transactions = create_category_and_entity_transactions(transaction_zero, installments)

        @collection[user_card_name][:with_installments] << Params::CardTransactionParamsService.new(
          card_transaction: { ct_description: transaction_zero[:ct_description], price:, date: transaction_zero[:date], user_id:, user_card_id: user_card.id },
          installments:,
          category_transactions:,
          entity_transactions:
        )
      end
    end

    def create_category_and_entity_transactions(trans, installments = [])
      category = @user.categories.find_or_create_by(category_name: trans[:category])
      category_transactions = [ { category_id: category.id } ]

      entity = @user.entities.find_or_create_by(entity_name: trans[:entity]) if trans[:entity].present?
      entity_transactions = create_entity_transactions(entity, trans[:is_payer], trans[:price], installments)

      [ category_transactions, entity_transactions ]
    end

    def create_entity_transactions(entity, is_payer, price, installments)
      return [] if entity.nil?

      exchanges_attributes = []

      if is_payer
        installments = [ { price: } ] if installments.blank?

        exchanges_attributes = installments.map do |installment|
          { exchange_type: :monetary, price: installment[:price] }
        end

        price = exchanges_attributes.pluck(:price).sum
      end

      [ { entity_id: entity.id, is_payer:, price:, exchanges_attributes: } ]
    end

    def prepare_installments(user_card, transaction_zero)
      user_card_name = user_card.user_card_name
      installments_count = transaction_zero[:installments_count]

      indexes = filter_indexes(user_card_name, transaction_zero, installments_count)
      indexes = filter_indexes_again(indexes, user_card_name, transaction_zero, installments_count) if indexes.count > installments_count
      indexes = filter_indexes_once_again(indexes, user_card_name, transaction_zero, installments_count) if indexes.count != installments_count

      installments = indexes.map do |index|
        installment = @collection[user_card_name][:with_pending_installments][index]

        { number: installment[:installment_id], price: installment[:price], month: installment[:ref_month], year: installment[:ref_year] }
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
        next if transaction[:entity] != transaction_zero[:entity]

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

    def create_transactions
      @collection.each do |user_card_name, datum|
        Rails.logger.info "[START] TRANSACTION CREATION #{user_card_name}.".blue

        datum = datum.values.flatten
        datum.each do |params_service|
          CardTransaction.create(params_service.params[:card_transaction])
        end

        Rails.logger.info "[ENDED] TRANSACTION CREATION #{user_card_name}.".green
      end
    end
  end
end

=begin # rubocop:disable all
xlsx_service = Import::FromXls.new(File.open(File.join("/mnt", "c", "Users", "Administrator", "Downloads", "finance.xlsx")))
xlsx_service.import
hash_service = Import::FromHash.new(xlsx_service.hash_collection)
hash_service.import

keys = hash_service.hash_collection.keys
keys.map do |key|
hash_service.hash_collection[key].select { |t| t[:entity] != "EXCHANGE" }.pluck(:category)
end.flatten.uniq
=end
