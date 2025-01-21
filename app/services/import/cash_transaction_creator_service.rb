# frozen_string_literal: true

module Import
  class CashTransactionCreatorService # rubocop:disable Metrics/ClassLength
    attr_reader :hash_collection
    attr_accessor :transactions_collection

    def initialize(main_service, transactions_collection = {})
      @main_service = main_service
      @hash_collection = @main_service.hash_cash_collection

      @transactions_collection = transactions_collection
    end

    delegate :log_with, to: LoggerService
    delegate :user, :user_id, :find_or_create_user_bank, :find_or_create_user_card, :create_category_and_entity_transactions, to: :@main_service

    def run
      create_cash_transactions_data
      create_cash_transactions
    end

    def create_cash_transactions_data
      log_with("CASH TRANSACTION DATA CREATION.") do
        create_cash_collection(@hash_collection)
      end
    end

    def create_cash_transactions
      log_with("CASH TRANSACTIONS CREATION.") do
        @transactions_collection.each_value do |transactions|
          transactions.each do |params_service|
            CashTransaction.create(params_service.params[:cash_transaction])
          end
        end
      end
    end

    private

    def create_cash_collection(transactions)
      standalone_transactions, transactions_with_installments = transactions.partition { |transaction| transaction[:installments_count] == 1 }

      create_standalone_transactions(standalone_transactions)
      create_transactions_with_installments(transactions_with_installments)
    end

    def create_standalone_transactions(standalone_transactions)
      @transactions_collection[:standalone] = standalone_transactions.map do |transaction|
        next if transaction[:entity] == "PREDICTION"

        if transaction[:category] == "INVESTMENT"
          user_bank_account_id = find_or_create_user_bank(transaction[:entity]).id
          Investment.create(transaction.slice(:description, :date, :month, :year, :price).merge(user_id:, user_bank_account_id:))
          next
        end

        if transaction[:category].in?([ "CARD ADVANCE", "CARD PAYMENT" ])
          user_card_id = find_or_create_user_card(transaction[:entity]).id
          add_card_payment_to_collection(user_card_id, transaction)
          next
        end

        cash_transaction = transaction.slice(:description, :price, :date, :month, :year).merge({ user_id: })

        category_transactions, entity_transactions = create_category_and_entity_transactions(transaction)

        Params::CashTransactionParams.new(cash_transaction:, cash_installments: { count: 1 }, category_transactions:, entity_transactions:)
      end.compact_blank
    end

    def create_transactions_with_installments(transactions_with_installments)
      @transactions_collection[:with_pending_installments] = transactions_with_installments
      @transactions_collection[:with_installments] = []

      while @transactions_collection[:with_pending_installments].any?
        transaction_zero = @transactions_collection[:with_pending_installments].first

        cash_installments = prepare_installments(transaction_zero, transaction_zero[:installments_count])
        price = cash_installments.pluck(:price).sum
        category_transactions, entity_transactions = create_category_and_entity_transactions(transaction_zero)

        @transactions_collection[:with_installments] <<
          Params::CashTransactionParams.new(
            cash_transaction: transaction_zero.slice(:description, :date, :month, :year).merge({ price:, user_id: }),
            cash_installments:,
            category_transactions:,
            entity_transactions:
          )
      end
    end

    def prepare_installments(transaction_zero, cash_installments)
      indexes = filter_indexes(transaction_zero, cash_installments)

      cash_installments = indexes.map do |index|
        installment = transactions_collection[:with_pending_installments][index]

        { number: installment[:installment_id], price: installment[:price], month: installment[:month], year: installment[:year] }
      end

      indexes.reverse_each do |index|
        transactions_collection[:with_pending_installments].delete_at(index)
      end

      cash_installments
    end

    def filter_indexes(transaction_zero, cash_installments)
      transactions_collection[:with_pending_installments].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != cash_installments
        next if transaction[:description] != transaction_zero[:description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:entity] != transaction_zero[:entity]

        index
      end.compact
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
      end
    end
  end
end
