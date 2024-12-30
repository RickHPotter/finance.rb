# frozen_string_literal: true

module Import
  class FinderService
    delegate :user, :user_id, to: :@main_service

    def initialize(main_service)
      @main_service = main_service
    end

    def create_user
      @main_service.user = User.find_or_create_by(first_name: "Rikki", last_name: "Potteru", email: "rikki.potteru@mail.com") do |user|
        user.password = "123123"
        user.confirmed_at = Date.current
      end
      @main_service.user_id = @main_service.user.id
    end

    def find_or_create_user_card(card_name)
      return @main_service.user_cards[card_name] if @main_service.user_cards[card_name]

      bank = Bank.find_or_create_by(bank_name: card_name, bank_code: card_name.upcase)
      card = Card.find_or_create_by(card_name: card_name, bank:)

      @main_service.user_cards[card_name] = UserCard.find_or_create_by(user:, card:, min_spend: 0, credit_limit: 1000, active: true) do |user_card|
        user_card.current_due_date = Date.current.end_of_month
        user_card.days_until_due_date = 7
      end
    end

    def find_or_create_user_bank(bank_name)
      return @main_service.user_banks[bank_name] if @main_service.user_banks[bank_name]

      bank = Bank.find_or_create_by(bank_name:, bank_code: bank_name.upcase)
      @main_service.user_banks[bank_name] = UserBankAccount.find_or_create_by(user:, bank:)
    end

    def find_or_create_category(category_name)
      return @main_service.categories[category_name] if @main_service.categories[category_name]

      @main_service.categories[category_name] = user.categories.find_or_create_by(category_name:)
    end

    def find_or_create_entity(entity_name)
      return @main_service.entities[entity_name] if @main_service.entities[entity_name]

      @main_service.entities[entity_name] = user.entities.find_or_create_by(entity_name:)
    end

    def create_category_and_entity_transactions(transaction)
      category = find_or_create_category(transaction[:category])
      category_transactions = [ { category_id: category.id } ]

      entity = find_or_create_entity(transaction[:entity]) if transaction[:entity].present?
      entity_transactions = []
      entity_transactions << { entity_id: entity.id, is_payer: false, price: 0.00, exchanges_attributes: [] } if entity.present?

      [ category_transactions, entity_transactions ]
    end
  end
end
