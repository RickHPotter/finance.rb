# frozen_string_literal: true

module Logic
  class CardTransactions
    def self.create_from(attributes = {})
      user_card = attributes[:user_card]
      entity = attributes[:entity]
      category = attributes[:category]

      if user_card.nil?
        user = entity&.user || category&.user
        user_card = user.user_cards.first
      end

      return if user_card.nil?

      card_transaction = user_card.card_transactions.new(date: Time.zone.now)
      card_transaction.build_month_year
      card_transaction.entity_transactions.new(entity:) if entity
      card_transaction.category_transactions.new(category:) if category
      card_transaction
    end
  end
end
