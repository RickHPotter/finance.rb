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

      bank = Bank.find_or_create_by(bank_code: 0)
      card = Card.find_or_create_by(bank:)

      @main_service.user_cards[card_name] =
        UserCard.find_or_create_by(user:, card:, user_card_name: card_name, days_until_due_date: 6, min_spend: 0, credit_limit: 1000 * 100, active: true)
    end

    def find_or_create_user_bank(bank_name)
      return @main_service.user_banks[bank_name] if @main_service.user_banks[bank_name]

      matched_bank = Bank.where("UPPER(bank_name) ILIKE ?", "%#{bank_name}%").first
      if matched_bank.present?
        UserBankAccount.find_or_create_by(user:, bank: matched_bank)
      else
        bank = Bank.find_or_create_by(bank_code: 0)
        UserBankAccount.create(user:, bank:)
      end => user_bank_account

      @main_service.user_banks[bank_name] = user_bank_account
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
      entity_transactions << { entity_id: entity.id, is_payer: false, price: 0, exchanges_attributes: [] } if entity.present?

      [ category_transactions, entity_transactions ]
    end
  end
end
