# frozen_string_literal: true

module Logic
  class CashTransactions
    def self.create_from(attributes = {})
      user_bank_account = attributes[:user_bank_account]
      entity = attributes[:entity]
      category = attributes[:category]

      if user_bank_account.nil?
        user = entity&.user || category&.user
        user_bank_account = user.user_bank_accounts.first
      end

      cash_transaction = user_bank_account.cash_transactions.new
      cash_transaction.build_month_year
      cash_transaction.entity_transactions.new(entity:) if entity
      cash_transaction.category_transactions.new(category:) if category
      cash_transaction
    end
  end
end
