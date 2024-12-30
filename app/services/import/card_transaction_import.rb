# frozen_string_literal: true

module Import
  class CardTransactionImport # rubocop:disable Metrics/ClassLength
    attr_reader :hash_collection, :cash_transaction_sheet, :cards_collection, :money_collection, :user, :user_id

    delegate :log_with, to: LoggerService

    def initialize(hash_collection, cash_transaction_sheet)
      @hash_collection = hash_collection
      @cash_transaction_sheet = cash_transaction_sheet
      @cards_collection = {}
      @money_collection = []
      @banks = {}
      @user_cards = {}
    end

    def import
      log_with do
        create_user
        create_card_transactions_data
        create_card_transactions

        create_cash_transactions_data
        create_cash_transactions
      end
    end

    def create_user
      @user = User.find_or_create_by(first_name: "Rikki", last_name: "Potteru", email: "rikki.potteru@mail.com") do |user|
        user.password = "123123"
        user.confirmed_at = Date.current
      end
      @user_id = @user.id
    end

    def create_card_transactions_data
      @hash_collection.except(cash_transaction_sheet).each do |card, transactions|
        log_with("CARD TRANSATION DATA CREATION #{card}.") do
          user_card = find_or_create_user_card(card)
          create_cards_collection(user_card, transactions)
        end
      end
    end

    def create_card_transactions
      @cards_collection.each do |user_card_name, datum|
        log_with("CARD TRANSACTIONS CREATION #{user_card_name}.") do
          datum = datum.values.flatten
          datum.each do |params_service|
            CardTransaction.create(params_service.params[:card_transaction].merge(imported: true))
          end
        end
      end
    end

    def create_cash_transactions_data
      @hash_collection[cash_transaction_sheet].each do |transaction|
        next if transaction[:price].zero?

        log_with("MONEY TRANSATION DATA CREATION.") do
          create_money_collection(transaction)
        end
      end
    end

    def create_cash_transactions
      log_with("MONEY TRANSACTIONS CREATION.") do
        @money_collection.each do |datum|
          datum = datum.values.flatten
          datum.each do |params_service|
            CardTransaction.create(params_service.params[:card_transaction].merge(imported: true))
          end
        end
      end
    end

    private

    def find_or_create_user_card(card_name)
      return @user_cards[card_name] if @user_cards[card_name]

      bank = Bank.find_or_create_by(bank_name: card_name, bank_code: card_name.upcase)
      card = Card.find_or_create_by(card_name: card_name, bank:)

      @user_cards[card_name] = UserCard.find_or_create_by(user:, card:, min_spend: 0, credit_limit: 1000, active: true) do |user_card|
        user_card.current_due_date = Date.current.end_of_month
        user_card.days_until_due_date = 7
      end
    end

    def find_or_create_create_user_bank(bank_name)
      return @banks[bank_name] if @banks[bank_name]

      @banks[bank_name] = Bank.find_or_create_by(bank_name:, bank_code: bank_name.upcase)
    end

    def create_cards_collection(user_card, transactions)
      @cards_collection[user_card.user_card_name] = {}

      standalone_transactions, transactions_with_installments = transactions.partition { |transaction| transaction[:installments_count] == 1 }

      create_standalone_transactions(user_card, standalone_transactions)
      create_transactions_with_installments(user_card, transactions_with_installments)
    end

    def create_money_collection(transaction)
      card_payment_options = [ "CARD ADVANCE", "CARD PAYMENT" ]

      user_card_id = find_or_create_user_card(transaction[:entity]).id
      user_bank_id = find_or_create_create_user_bank(transaction[:bank])

      add_card_payment_to_collection(user_card_id, transaction)               and return if transaction[:category].in?(card_payment_options)
      add_middleware_to_collection(user_card_id, user_bank_id, transaction)   and return if transaction[:category] == "MIDDLEWARE"
      add_investment_to_collection(user_card_id, user_bank_id, transaction)   and return if transaction[:category] == "INVESTMENT"
      add_exchange_to_collection(user_card_id, user_bank_id, transaction)     and return if transaction[:category] == "EXCHANGE"
    end

    def add_card_payment_to_collection(user_card_id, transaction)
      return if transaction[:date].blank?

      params = transaction.slice(:month, :year, :price).merge(user_card_id:, categories: { category_name: transaction[:category] })

      if transaction[:category] == "CARD PAYMENT"
        cash_transaction = @user.cash_transactions.joins(:categories).find_by(params)
        cash_transaction.update!(date: transaction[:date])
      else
        advance_cash_transaction = @user.advance_cash_transactions.joins(:categories).find_by(params)
        advance_cash_transaction.update!(date: transaction[:date])

        card_transaction = @user.card_transactions.joins(:categories).find_by(params.merge(price: params[:price] * -1))
        card_transaction.update!(date: transaction[:date])
      end
    rescue ActiveRecord::RecordInvalid
      raise StandardError, "Transaction not found: #{transaction}. Data must be wrong in one place or another"
    end

    def add_exchange_to_collection(user_card_id, user_bank_id, transaction); end
    def add_middleware_to_collection(user_card_id, user_bank_id, transaction); end
    def add_investment_to_collection(user_card_id, user_bank_id, transaction); end

    def create_standalone_transactions(user_card, standalone_transactions)
      @cards_collection[user_card.user_card_name][:standalone] = standalone_transactions.map do |trans|
        card_transaction = trans.slice(:description, :price, :date, :month, :year).merge({ user_id:, user_card_id: user_card.id })
        category_transactions, entity_transactions = create_category_and_entity_transactions(trans)

        Params::CardTransactionParams.new(card_transaction:, installments: { count: 1 }, category_transactions:, entity_transactions:)
      end
    end

    def create_transactions_with_installments(user_card, transactions_with_installments)
      user_card_name = user_card.user_card_name

      @cards_collection[user_card_name][:with_pending_installments] = transactions_with_installments
      @cards_collection[user_card_name][:with_installments] = []

      while @cards_collection[user_card_name][:with_pending_installments].any?
        transaction_zero = @cards_collection[user_card_name][:with_pending_installments].first

        installments = prepare_installments(user_card, transaction_zero)
        price = installments.pluck(:price).sum
        category_transactions, entity_transactions = create_category_and_entity_transactions(transaction_zero, installments)

        @cards_collection[user_card_name][:with_installments] << Params::CardTransactionParams.new(
          card_transaction: transaction_zero.slice(:description, :date, :month, :year).merge({ price:, user_id:, user_card_id: user_card.id }),
          installments:,
          category_transactions:,
          entity_transactions:
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
        installment = @cards_collection[user_card_name][:with_pending_installments][index]

        { number: installment[:installment_id], price: installment[:price], month: installment[:month], year: installment[:year] }
      end

      indexes.reverse_each do |index|
        @cards_collection[user_card_name][:with_pending_installments].delete_at(index)
      end

      validate_installments(transaction_zero, installments)
    end

    def filter_indexes(user_card_name, transaction_zero, installments_count)
      @cards_collection[user_card_name][:with_pending_installments].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != installments_count
        next if transaction[:description] != transaction_zero[:description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:entity] != transaction_zero[:entity]

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, installments_count, transaction_zero[:description])
    end

    def filter_indexes_again(indexes, user_card_name, transaction_zero, installments_count)
      indexes.map do |index|
        transaction = @cards_collection[user_card_name][:with_pending_installments][index]

        next if transaction[:price] - transaction_zero[:price] <= transaction_zero[:price] * 0.06
        next if transaction[:price] - transaction_zero[:price] >= transaction_zero[:price] * 0.06 * -1

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, installments_count, transaction_zero[:description])
    end

    def filter_indexes_once_again(indexes, user_card_name, transaction_zero, installments_count)
      transaction_zero_date = transaction_zero[:date]
      transaction_zero_reference = Date.new(2000 + transaction_zero[:year], transaction_zero[:month])

      new_indexes = []
      indexes.each do |index|
        installment = @cards_collection[user_card_name][:with_pending_installments][index]
        pos = new_indexes.count
        next_pos = pos + 1

        installment_number = installment[:installment_id]
        installment_date = installment[:date]
        installment_reference = Date.new(2000 + installment[:year], installment[:month])

        next if installment_number != next_pos
        next if installment_date != transaction_zero_date.next_month(pos)
        next if installment_reference != transaction_zero_reference.next_month(pos)

        new_indexes << index
      end

      validate_installments_count_by_indexes(new_indexes, installments_count, transaction_zero[:description])
    end

    def validate_installments_count_by_indexes(indexes, installments_count, description)
      return indexes if indexes.count >= installments_count

      raise StandardError, "Expected #{installments_count} installments, got: #{indexes.count} for #{description}."
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

    def create_category_and_entity_transactions(transaction, installments = [])
      category = @user.categories.find_or_create_by(category_name: transaction[:category])
      category_transactions = [ { category_id: category.id } ]

      entity = @user.entities.find_or_create_by(entity_name: transaction[:entity]) if transaction[:entity].present?
      entity_transactions = create_entity_transactions(entity, transaction[:is_payer], transaction[:price], installments)

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
  end
end
