# frozen_string_literal: true

module Logic
  class UserCards
    def self.create(user_card_params)
      user_card = UserCard.new(user_card_params)
      _handle_creation(user_card)
    end

    def self.find_by(user, conditions)
      # FIXME: create counter_cache and card_transactions_total
      user.user_cards
          .left_joins(:card_transactions)
          .includes(:card)
          .where(conditions)
          .group("user_cards.id")
          .select("user_cards.*", "COUNT(DISTINCT card_transactions.id) AS card_transactions_count", "SUM(card_transactions.price) AS card_transactions_total")
          .order(user_card_name: :asc)
    end

    def self.update(user_card, user_card_params)
      user_card.assign_attributes(user_card_params)
      _handle_creation(user_card)
    end

    def self._handle_creation(user_card)
      return user_card if user_card.current_closing_date.nil? || user_card.current_due_date.nil?

      user_card.days_until_due_date = user_card.current_closing_date.day - user_card.current_due_date.day
      user_card.save
      user_card
    end
  end
end
