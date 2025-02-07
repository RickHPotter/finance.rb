# frozen_string_literal: true

module Params
  class CashTransactions
    attr_accessor :description, :date, :month, :year, :price, :user_id, :user_card_id, :cash_installments, :category_transactions, :entity_transactions

    def initialize(cash_transaction: {}, cash_installments: {}, category_transactions: {}, entity_transactions: {})
      assign_cash_transaction(cash_transaction)

      @cash_installments = cash_installments
      @entity_transactions = entity_transactions
      @category_transactions = category_transactions
    end

    def params
      {
        cash_transaction: {
          description: description || "New CashTransaction #{DateTime.current.to_i}",
          date:,
          month:,
          year:,
          price:,
          user_id:,
          user_card_id:,
          cash_installments_attributes:,
          category_transactions_attributes:,
          entity_transactions_attributes:
        }
      }
    end

    # no base => cash_installments = { count: 2 }
    # base    => cash_installments = [ {}, {} ]
    def cash_installments_attributes
      return cash_installments if cash_installments.is_a? Array

      count = cash_installments[:count] || 1
      installment_price = (price / count).round(2)

      (1..count).map do |i|
        { number: i, date: date.next_month(i - 1), month:, year:, price: installment_price }
      end
    end

    # no base, base => category_transactions = [ {}, {} ]
    def category_transactions_attributes
      category_transactions
    end

    # no base => cash_installments = [ {}, {} ]
    # base    => cash_installments = [ {}, {} ] # includes :id
    def entity_transactions_attributes
      return entity_transactions if entity_transactions&.first&.try(:id)

      entity_transactions.map do |entity_transaction|
        exchanges = entity_transaction[:exchanges_attributes]
        exchanges_attributes = exchanges.map.with_index { |exchange, i| exchange.merge(number: i + 1) }
        is_payer = exchanges_attributes.present?
        status = exchanges_attributes.present? ? :pending : :finished

        entity_transaction.merge(is_payer:, status:, transactable_type: "CashTransaction", exchanges_attributes:)
      end
    end

    def use_base(cash_transaction, cash_transaction_options: {}, entity_transactions_options: {})
      cash_transaction = CashTransaction.includes(:cash_installments, :entity_transactions, :category_transactions).where(id: cash_transaction.id).first

      assign_cash_transaction(cash_transaction, cash_transaction_options:)
      assign_cash_installments(cash_transaction.cash_installments)
      assign_category_transactions(cash_transaction.category_transactions)
      assign_entity_transactions(cash_transaction.entity_transactions, entity_transactions_options:)
    end

    private

    def assign_cash_transaction(cash_transaction, cash_transaction_options: {})
      @description    = cash_transaction_options[:description]    || cash_transaction[:description]
      @date           = cash_transaction_options[:date]           || cash_transaction[:date]
      @month          = cash_transaction_options[:month]          || cash_transaction[:month]
      @year           = cash_transaction_options[:year]           || cash_transaction[:year]
      @price          = cash_transaction_options[:price]          || cash_transaction[:price]
      @user_id        = cash_transaction_options[:user_id]        || cash_transaction[:user_id]
      @user_card_id   = cash_transaction_options[:user_card_id]   || cash_transaction[:user_card_id]
    end

    def assign_cash_installments(cash_installments)
      @cash_installments = cash_installments.map do |installment|
        installment.slice(:id, :number, :date, :month, :year, :price).merge(installment_type: :CashInstallment)
      end
    end

    def assign_category_transactions(category_transactions)
      @category_transactions = category_transactions.map do |category_transaction|
        {
          id: category_transaction.id,
          category_id: category_transaction.category_id,
          transactable_type: category_transaction.transactable_type,
          transactable_id: category_transaction.transactable_id
        }
      end
    end

    def assign_entity_transactions(entity_transactions, entity_transactions_options: {})
      is_payer_option = entity_transactions_options[:is_payer]
      exchange_type_option = entity_transactions_options[:exchange_type]

      @entity_transactions = entity_transactions.map do |entity_transaction|
        exchanges = entity_transaction.exchanges.map(&:attributes).map(&:symbolize_keys)
        exchanges = [ { number: 1, price: entity_transaction.price } ] if exchanges.blank? && is_payer_option
        exchanges = exchanges.each { |exchange| exchange[:exchange_type] = exchange_type_option } if exchange_type_option

        {
          id: entity_transaction.id,
          is_payer: is_payer_option || entity_transaction.is_payer,
          entity_id: entity_transaction.entity_id,
          price: entity_transaction.price,
          exchanges_attributes: exchanges
        }
      end
    end
  end
end
