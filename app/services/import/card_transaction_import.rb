# frozen_string_literal: true

module Import
  class CardTransactionImport # rubocop:disable Metrics/ClassLength
    attr_reader :hash_collection, :money_transaction_sheet, :cards_collection, :money_collection, :user, :user_id

    delegate :log_with, to: LoggerService

    def initialize(hash_collection, money_transaction_sheet)
      @hash_collection = hash_collection
      @money_transaction_sheet = money_transaction_sheet
      @cards_collection = {}
      @money_collection = []
    end

    def import
      log_with do
        create_user
        create_card_transactions_data
        create_card_transactions

        create_money_transactions_date
        create_money_transactions
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
      @hash_collection.except(money_transaction_sheet).each do |card, transactions|
        log_with("CARD TRANSATION DATA CREATION #{card}.") do
          user_card = create_user_card(card)
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

    def create_money_transactions_date
      @hash_collection[money_transaction_sheet].each do |transactions|
        log_with("MONEY TRANSATION DATA CREATION.") do
          create_money_collection(transactions)
        end
      end
    end

    def create_money_transactions
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

    def create_user_card(card_name)
      bank = Bank.find_or_create_by(bank_name: card_name, bank_code: card_name.upcase)
      card = Card.find_or_create_by(card_name: card_name, bank:)

      UserCard.find_or_create_by(user:, card:, min_spend: 0, credit_limit: 1000, active: true) do |user_card|
        user_card.current_due_date = Date.current.end_of_month
        user_card.days_until_due_date = 7
      end
    end

    def create_cards_collection(user_card, transactions)
      @cards_collection[user_card.user_card_name] = {}

      standalone_transactions, transactions_with_installments = transactions.partition { |trans| trans[:installments_count] == 1 }

      create_standalone_transactions(user_card, standalone_transactions)
      create_transactions_with_installments(user_card, transactions_with_installments)
    end

    def create_money_collection(transaction)
      card_payment_options = %w[ADVANCE PAYMENT REVERSAL]
      # is_an_exchange    = %w[EXCHANGE]
      # is_a_middleware   = %w[MIDDLEWARE]
      # is_an_investment  = %w[INVESTMENT]

      # [ "BET", "BENEFITS", "BILL", "DEPOSIT", "EDUCATION", "FEES", "FOOD", "GROCERY", "NEEDS", "GIFT",
      #   "GODSEND", "LEISURE", "MORAL DEBT", "PROMO", "RENT", "SALARY", "SELL", "TRANSPORT" ]

      # @money_collection << params and
      return if transaction[:entity].in? %w[NBNK AME]

      if card_payment_options.include?(transaction[:category])
        user_card_id = @user.user_cards.find_by(user_card_name: transaction[:entity])
        payment = @user.money_transactions.find_by(transaction.slice(:month, :year).merge(money_transaction_type: "Installment", user_card_id:))
        if transaction[:category].in? %w[ADVANCE REVERSAL]
          payment = @user.card_transactions.find_by(transaction.slice(:month, :year, :ct_description, :price).merge(user_card_id:))
        end

        params = { date: transaction[:date], user_card_id: user_card_id, month: transaction[:month], year: transaction[:year], price: transaction[:price] }

        case [ payment.present?, transaction[:category] ]
        in [ true, "PAYMENT" ]
          debugger if payment.price != transaction[:price]
          payment.update(date: transaction[:date]) and return
        in [ true, "ADVANCE" ]
          debugger if payment.price != transaction[:price]
          payment.update(date: transaction[:date]) and return
        in [ false, _category ]
          params[:ct_description] = "#{transaction[:ct_description]} (MANUAL)"
        in [ condition, category ]
          debugger
        else
          debugger
        end

      end

      # user_bank = create_user_bank(transaction[:bank])
      entity = transaction[:entity]
    end

    def create_user_bank(bank_name)
      Bank.find_or_create_by(bank_name:, bank_code: bank_name.upcase)
    end

    def create_standalone_transactions(user_card, standalone_transactions)
      @cards_collection[user_card.user_card_name][:standalone] = standalone_transactions.map do |trans|
        card_transaction = trans.slice(:ct_description, :price, :date, :month, :year).merge({ user_id:, user_card_id: user_card.id })
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
          card_transaction: transaction_zero.slice(:ct_description, :date, :month, :year).merge({ price:, user_id:, user_card_id: user_card.id }),
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
        next if transaction[:ct_description] != transaction_zero[:ct_description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:entity] != transaction_zero[:entity]

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, installments_count, transaction_zero[:ct_description])
    end

    def filter_indexes_again(indexes, user_card_name, transaction_zero, installments_count)
      indexes.map do |index|
        transaction = @cards_collection[user_card_name][:with_pending_installments][index]

        next if transaction[:price] - transaction_zero[:price] <= transaction_zero[:price] * 0.06
        next if transaction[:price] - transaction_zero[:price] >= transaction_zero[:price] * 0.06 * -1

        index
      end.compact => indexes

      validate_installments_count_by_indexes(indexes, installments_count, transaction_zero[:ct_description])
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
  end
end
