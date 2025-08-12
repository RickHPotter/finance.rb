# frozen_string_literal: true

module Logic
  class RecalculateCountAndTotalService
    def initialize(card_transaction: nil, cash_transaction: nil)
      raise ArgumentError if card_transaction.nil? && cash_transaction.nil?

      @card_transaction = card_transaction
      @cash_transaction = cash_transaction
    end

    def call
      recalculate_card_transaction if @card_transaction
      recalculate_cash_transaction if @cash_transaction
    end

    def recalculate_card_transaction
      user_card  = @card_transaction.user_card
      categories = @card_transaction.categories
      entities   = @card_transaction.entities

      user_card&.update_columns(card_transactions_total: user_card.card_transactions.sum(:price))
      categories.each(&:update_card_transactions_count_and_total)
      entities.each(&:update_card_transactions_count_and_total)
    end

    def recalculate_cash_transaction
      user_bank_account = @cash_transaction.user_bank_account
      categories        = @cash_transaction.categories
      entities          = @cash_transaction.entities

      user_bank_account&.update_columns(cash_transactions_total: user_bank_account.cash_transactions.sum(:price))
      categories.each(&:update_cash_transactions_count_and_total)
      entities.each(&:update_cash_transactions_count_and_total)
    end
  end
end
