# frozen_string_literal: true

module Import
  class CashTransactionCreatorService
    attr_reader :hash_collection
    attr_accessor :transactions_collection

    def initialize(main_service, transactions_collection = [])
      @main_service = main_service
      @hash_collection = @main_service.hash_cash_collection

      @transactions_collection = transactions_collection
    end

    delegate :log_with, to: LoggerService
    delegate :user, :user_id, :find_or_create_user_bank, :find_or_create_user_card, :create_category_and_entity_transactions, to: :@main_service

    def run
      create_cash_transactions_data
      # date    xl -> app
      # 2021-08 13 -> 13
      # 2021-09 31 -> 31
      # 2021-10 24 -> 23 > -1
      # 2021-11 36 -> 34 > -2
      # 2021-12 27 -> 29 > +2
      # 2022-01 31 -> 32 > +1
      # 2022-02 31 -> 32 > +1
      # 2022-05 78 -> 76 > -2
      # 2022-07 65 -> 59 > -6
      # 2022-08 30 -> 26 > -4
      # 2022-09 45 -> 42 > -3
      # 2022-10 31 -> 28 > -3
      # 2022-11 35 -> 33 > -2
      # 2022-12 36 -> 35 > -1
      # 2023-01 47 -> 44 > -3
      # 2023-02 34 -> 33 > -1
      # 2023-03 44 -> 43 > -1
      # 2023-04 30 -> 30
      # 2023-05 34 -> 33 > -1
      # 2023-06 26 -> 26
      # 2023-07 38 -> 38
      # 2023-08 45 -> 42 > -3
      # 2023-09 54 -> 54
      # 2023-10 54 -> 53 > -1
      # 2023-11 42 -> 43 > +1
      # 2023-12 42 -> 42
      # 2024-01 38 -> 38
      # 2024-02 39 -> 39
      # 2024-03 46 -> 45 > -1
      # 2024-04 28 -> 28
      # 2024-05 38 -> 38
      # 2024-06 37 -> 37
      # 2024-07 47 -> 47
      # 2024-08 39 -> 39
      # 2024-09 39 -> 39
      # 2024-10 32 -> 33 > +1
      # 2024-11 41 -> 41
      # 2024-12 50 -> 50
      # 2025-01
      create_cash_transactions
    end

    def create_cash_transactions_data
      @hash_collection.each do |transaction|
        next if transaction[:price].zero?

        log_with("MONEY TRANSATION DATA CREATION.") do
          create_cash_collection(transaction)
        end
      end
    end

    def create_cash_transactions
      log_with("MONEY TRANSACTIONS CREATION.") do
        @transactions_collection.each do |transaction|
          category_transactions_attributes, entity_transactions_attributes = create_category_and_entity_transactions(transaction)

          transaction.except!(:category, :entity, :is_payer).merge!(category_transactions_attributes:, entity_transactions_attributes:)
          CashTransaction.create(transaction)
        end
      end
    end

    private

    def create_cash_collection(transaction)
      if transaction[:category] == "INVESTMENT"
        user_bank_account_id = find_or_create_user_bank(transaction[:bank]).id
        add_investment_to_collection(user_bank_account_id, transaction)
        return
      end

      if transaction[:category].in?([ "CARD ADVANCE", "CARD PAYMENT" ])
        user_card_id = find_or_create_user_card(transaction[:entity]).id
        add_card_payment_to_collection(user_card_id, transaction)
        return
      end

      params = transaction.slice(:description, :date, :month, :year, :price, :category, :entity).merge(user_id:, is_payer: false)
      params[:comment] = "MANUAL EXCHANGE #{transaction[:entity]}" if transaction[:category] == "EXCHANGE" && transaction[:entity] != "MOI"

      @transactions_collection << params
    end

    def add_investment_to_collection(user_bank_account_id, transaction)
      Investment.create(transaction.slice(:date, :month, :year, :price).merge(user_id:, user_bank_account_id:))
    end

    def add_card_payment_to_collection(user_card_id, transaction)
      params = transaction.slice(:month, :year, :price).merge(user_card_id:, categories: { category_name: transaction[:category] })

      case transaction[:category]
      when "CARD PAYMENT"
        cash_transaction = user.cash_transactions.joins(:categories).find_by(params)
        cash_transaction.update(date: transaction[:date])
      when "CARD ADVANCE"
        params[:price] *= -1
        card_transaction = user.card_transactions.joins(:categories).find_by(params)
        card_transaction.update(date: transaction[:date])
      else
        params[:comment] = "MANUAL #{transaction[:category]}"
        params[:category] = transaction[:category]
        params[:entity] = transaction[:entity]

        @transactions_collection << params
      end
    end
  end
end
