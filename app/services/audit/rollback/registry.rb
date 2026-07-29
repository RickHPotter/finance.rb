# frozen_string_literal: true

class Audit::Rollback::Registry
  ADAPTERS = {
    "CashTransaction" => Audit::Rollback::Adapters::CashTransaction,
    "CardTransaction" => Audit::Rollback::Adapters::CardTransaction,
    "CashInstallment" => Audit::Rollback::Adapters::Installment,
    "CardInstallment" => Audit::Rollback::Adapters::Installment,
    "CategoryTransaction" => Audit::Rollback::Adapters::CategoryTransaction,
    "EntityTransaction" => Audit::Rollback::Adapters::EntityTransaction,
    "Budget" => Audit::Rollback::Adapters::Budget,
    "BudgetCategory" => Audit::Rollback::Adapters::BudgetCategory,
    "BudgetEntity" => Audit::Rollback::Adapters::BudgetEntity,
    "Reference" => Audit::Rollback::Adapters::Reference,
    "UserCard" => Audit::Rollback::Adapters::UserCard,
    "UserBankAccount" => Audit::Rollback::Adapters::UserBankAccount,
    "Subscription" => Audit::Rollback::Adapters::Subscription,
    "Investment" => Audit::Rollback::Adapters::Investment
  }.freeze

  class << self
    def build(transition:, operation_keys:, transitions: [])
      adapter_class = ADAPTERS[transition.record_type]
      adapter_class&.new(transition:, operation_keys:, transitions:)
    end

    def supported_types
      ADAPTERS.keys
    end
  end
end
