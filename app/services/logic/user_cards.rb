# frozen_string_literal: true

module Logic
  class UserCards
    def self.create(user_card_params)
      user_card = UserCard.new(user_card_params)
      _handle_creation(user_card)
    end

    def self.update(user_card, user_card_params)
      user_card.assign_attributes(user_card_params)
      _handle_creation(user_card)
    end

    def self.find_by(user, conditions)
      user.user_cards
          .left_joins(:card_transactions)
          .includes(:card)
          .where(conditions)
          .group("user_cards.id")
          .order(user_card_name: :asc)
    end

    def self._handle_creation(user_card)
      user_card.save
      user_card
    end
  end
end
