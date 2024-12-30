# frozen_string_literal: true

module Import
  class CardTransactionCreatorService
    attr_reader :hash_collection, :installment_initialiser_service
    attr_accessor :transactions_collection

    def initialize(main_service, transactions_collection = {})
      @main_service = main_service
      @hash_collection = @main_service.hash_cards_collection

      @transactions_collection = transactions_collection

      @installment_initialiser_service ||= Import::InstallmentInitialiserService.new(self)
    end

    delegate :log_with, to: LoggerService
    delegate :user, :user_id, :find_or_create_user_card, :create_category_and_entity_transactions, to: :@main_service
    delegate :prepare_installments, to: :installment_initialiser_service

    def run
      create_card_transactions_data
      create_card_transactions
    end

    def create_card_transactions_data
      @hash_collection.each do |card_name, transactions|
        log_with("CARD TRANSATION DATA CREATION #{card_name}.") do
          user_card = find_or_create_user_card(card_name)
          create_cards_collection(user_card, transactions)
        end
      end
    end

    def create_card_transactions
      @transactions_collection.each do |user_card_name, transactions_divided_by_types|
        log_with("CARD TRANSACTIONS CREATION #{user_card_name}.") do
          transactions = transactions_divided_by_types.values.flatten

          transactions.each do |params_service|
            CardTransaction.create(params_service.params[:card_transaction].merge(imported: true))
          end
        end
      end
    end

    private

    def create_cards_collection(user_card, transactions)
      @transactions_collection[user_card.user_card_name] = {}

      standalone_transactions, transactions_with_installments = transactions.partition { |transaction| transaction[:installments_count] == 1 }

      create_standalone_transactions(user_card, standalone_transactions)
      create_transactions_with_installments(user_card, transactions_with_installments)
    end

    def create_standalone_transactions(user_card, standalone_transactions)
      @transactions_collection[user_card.user_card_name][:standalone] = standalone_transactions.map do |transaction|
        card_transaction = transaction.slice(:description, :price, :date, :month, :year).merge({ user_id:, user_card_id: user_card.id })
        category_transactions, entity_transactions = create_category_and_entity_transactions(transaction)

        Params::CardTransactionParams.new(card_transaction:, installments: { count: 1 }, category_transactions:, entity_transactions:)
      end
    end

    def create_transactions_with_installments(user_card, transactions_with_installments)
      user_card_name = user_card.user_card_name

      @transactions_collection[user_card_name][:with_pending_installments] = transactions_with_installments
      @transactions_collection[user_card_name][:with_installments] = []

      while @transactions_collection[user_card_name][:with_pending_installments].any?
        transaction_zero = @transactions_collection[user_card_name][:with_pending_installments].first

        installments = prepare_installments(user_card, transaction_zero)
        price = installments.pluck(:price).sum
        category_transactions, entity_transactions = create_category_and_entity_transactions(transaction_zero)

        @transactions_collection[user_card_name][:with_installments] << Params::CardTransactionParams.new(
          card_transaction: transaction_zero.slice(:description, :date, :month, :year).merge({ price:, user_id:, user_card_id: user_card.id }),
          installments:,
          category_transactions:,
          entity_transactions:
        )
      end
    end
  end
end
