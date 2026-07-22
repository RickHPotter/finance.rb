# frozen_string_literal: true

class Audit::VersionMetadata
  ALLOWED_ATTRIBUTES = {
    "CashTransaction" => %w[user_bank_account_id user_card_id subscription_id reference_transactable_type reference_transactable_id],
    "CardTransaction" => %w[user_card_id subscription_id advance_cash_transaction_id reference_transactable_type reference_transactable_id],
    "CashInstallment" => %w[cash_transaction_id],
    "CardInstallment" => %w[card_transaction_id cash_transaction_id],
    "CategoryTransaction" => %w[transactable_type transactable_id category_id],
    "EntityTransaction" => %w[transactable_type transactable_id entity_id],
    "Exchange" => %w[entity_transaction_id cash_transaction_id],
    "Reference" => %w[user_card_id],
    "UserCard" => %w[card_id],
    "UserBankAccount" => %w[bank_id],
    "Budget" => [],
    "Subscription" => [],
    "Investment" => %w[user_bank_account_id investment_type_id cash_transaction_id piggy_bank_return_cash_transaction_id],
    "PiggyBank" => %w[source_cash_transaction_id return_cash_transaction_id]
  }.freeze

  class << self
    def for(record)
      allowed_attributes = ALLOWED_ATTRIBUTES.fetch(record.class.name)
      record.attributes.slice(*allowed_attributes).compact
    end
  end
end
