# frozen_string_literal: true

module Params
  class CardTransactions
    attr_accessor :description, :date, :month, :year, :price, :paid, :user_id, :user_card_id, :card_installments, :category_transactions, :entity_transactions

    def initialize(card_transaction: {}, card_installments: {}, category_transactions: {}, entity_transactions: {})
      assign_card_transaction(card_transaction)

      @card_installments = card_installments
      @entity_transactions = entity_transactions
      @category_transactions = category_transactions
    end

    def params
      {
        card_transaction: {
          description: description || "New CardTransaction #{DateTime.current.to_i}",
          date:,
          month:,
          year:,
          price:,
          paid:,
          user_id:,
          user_card_id:,
          card_installments_attributes:,
          category_transactions_attributes:,
          entity_transactions_attributes:
        }
      }
    end

    # no base => card_installments = { count: 2 }
    # base    => card_installments = [ {}, {} ]
    def card_installments_attributes
      return card_installments if card_installments.is_a? Array

      count = card_installments[:count] || 1
      installment_price = price / count

      (1..count).map do |i|
        paid = date.present? && date + i.months <= Date.current
        { number: i, date: date.next_month(i - 1), month:, year:, price: installment_price, paid: }
      end
    end

    # no base, base => category_transactions = [ {}, {} ]
    def category_transactions_attributes
      category_transactions
    end

    # no base => card_installments = [ {}, {} ]
    # base    => card_installments = [ {}, {} ] # includes :id
    def entity_transactions_attributes
      return entity_transactions if entity_transactions&.first&.try(:id)

      entity_transactions.map do |entity_transaction|
        exchanges = entity_transaction[:exchanges_attributes]
        exchanges_attributes = exchanges.map.with_index { |exchange, i| exchange.merge(number: i + 1) }
        is_payer = exchanges_attributes.present?
        status = exchanges_attributes.present? ? :pending : :finished

        entity_transaction.merge(is_payer:, status:, transactable_type: "CardTransaction", exchanges_attributes:)
      end
    end

    def use_base(card_transaction, card_transaction_options: {}, entity_transactions_options: {})
      card_transaction = CardTransaction.includes(:card_installments, :entity_transactions, :category_transactions).where(id: card_transaction.id).first

      assign_card_transaction(card_transaction, card_transaction_options:)
      assign_card_installments(card_transaction.card_installments)
      assign_category_transactions(card_transaction.category_transactions)
      assign_entity_transactions(card_transaction.entity_transactions, entity_transactions_options:)
    end

    private

    def assign_card_transaction(card_transaction, card_transaction_options: {})
      @description  = card_transaction_options[:description]  || card_transaction[:description]
      @date         = card_transaction_options[:date]         || card_transaction[:date]
      @month        = card_transaction_options[:month]        || card_transaction[:month]
      @year         = card_transaction_options[:year]         || card_transaction[:year]
      @price        = card_transaction_options[:price]        || card_transaction[:price]
      @paid         = card_transaction_options[:paid]         || card_transaction[:paid]
      @user_id      = card_transaction_options[:user_id]      || card_transaction[:user_id]
      @user_card_id = card_transaction_options[:user_card_id] || card_transaction[:user_card_id]
    end

    def assign_card_installments(card_installments)
      @card_installments = card_installments.map do |installment|
        installment.slice(:id, :number, :date, :month, :year, :price, :paid).merge(installment_type: :CardInstallment)
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
          price_to_be_returned: is_payer_option ? entity_transaction.price_to_be_returned : 0,
          exchanges_attributes: exchanges
        }
      end
    end
  end
end
