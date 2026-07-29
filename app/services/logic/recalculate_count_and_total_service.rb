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
      categories = persisted_categories_for(@card_transaction)
      entities   = persisted_entities_for(@card_transaction)

      user_card&.update_columns(card_transactions_total: user_card.card_transactions.sum(:price))
      categories.each(&:update_card_transactions_count_and_total)
      entities.each(&:update_card_transactions_count_and_total)
    end

    def recalculate_cash_transaction
      user_bank_account = @cash_transaction.user_bank_account
      categories        = persisted_categories_for(@cash_transaction)
      entities          = persisted_entities_for(@cash_transaction)

      user_bank_account&.update_columns(cash_transactions_total: user_bank_account.cash_transactions.sum(:price))
      categories.each(&:update_cash_transactions_count_and_total)
      entities.each(&:update_cash_transactions_count_and_total)
    end

    private

    def persisted_categories_for(transaction)
      return transaction.categories unless transaction.persisted?

      category_ids = CategoryTransaction.where(transactable: transaction).select(:category_id)
      Category.where(id: category_ids)
    end

    def persisted_entities_for(transaction)
      return transaction.entities unless transaction.persisted?

      entity_ids = EntityTransaction.where(transactable: transaction).select(:entity_id)
      Entity.where(id: entity_ids)
    end
  end
end
