# frozen_string_literal: true

module Import
  class FinderService
    delegate :user, :user_id, to: :@main_service

    def initialize(main_service)
      @main_service = main_service
    end

    def create_user
      @main_service.user = User.find_or_create_by(first_name: "Rikki", last_name: "Potteru", email: "rikki.potteru@mail.com", locale: :en) do |user|
        user.password = "123123"
        user.confirmed_at = Time.zone.today
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
        UserBankAccount.find_or_create_by(user:, bank: matched_bank, user_bank_account_name: bank_name, account_number: UserBankAccount.ids.last.to_i + 1)
      else
        bank = Bank.find_or_create_by(bank_code: 0)
        UserBankAccount.create(user:, bank:, user_bank_account_name: bank_name, account_number: UserBankAccount.ids.last.to_i + 1)
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
      categories = transaction[:category].map do |category_name|
        find_or_create_category(category_name)
      end

      category_transactions = categories.map do |category|
        { category_id: category.id }
      end

      entities = transaction[:entity].map do |entity_name|
        find_or_create_entity(entity_name)
      end

      entity_transactions = entities.map do |entity|
        { entity_id: entity.id, is_payer: false, price: 0, exchanges_attributes: [] }
      end

      [ category_transactions, entity_transactions ]
    end
  end
end
