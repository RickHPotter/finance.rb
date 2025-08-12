# frozen_string_literal: true

module Import
  class MainService
    attr_reader :user_hash, :hash_cards_collection, :hash_cash_collection, :finder_service, :card_transaction_creator_service, :cash_transaction_creator_service
    attr_accessor :cards_collection, :cash_collection, :user, :user_id, :categories, :entities, :user_banks, :user_cards

    delegate :log_with,                                to: LoggerService
    delegate :create_user,                             to: :finder_service
    delegate :find_or_create_user_card,                to: :finder_service
    delegate :find_or_create_user_bank,                to: :finder_service
    delegate :find_or_create_entity,                   to: :finder_service
    delegate :create_category_and_entity_transactions, to: :finder_service
    delegate :create_card_transactions,                to: :card_transaction_creator_service

    def initialize(user_hash, hash_collection, cash_transaction_sheet)
      @user_hash = user_hash

      @hash_cards_collection = hash_collection.except(cash_transaction_sheet)
      @hash_cash_collection  = hash_collection[cash_transaction_sheet]
      @categories = {}
      @entities   = {}
      @user_banks = {}
      @user_cards = {}

      @finder_service                   ||= Import::FinderService.new(self)
      @card_transaction_creator_service ||= Import::CardTransactionCreatorService.new(self)
      @cash_transaction_creator_service ||= Import::CashTransactionCreatorService.new(self)
    end

    def import
      log_with do
        create_user(user_hash)
        @card_transaction_creator_service.run
        @cash_transaction_creator_service.run
      end
    end
  end
end
