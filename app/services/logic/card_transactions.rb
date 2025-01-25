# frozen_string_literal: true

module Logic
  class CardTransactions
    def self.create_from_user_card(user_card)
      card_transaction = user_card.card_transactions.new
      card_transaction.build_month_year
      card_transaction
    end
  end
end
