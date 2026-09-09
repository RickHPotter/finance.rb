# frozen_string_literal: true

class Audit::Rollback::Adapters::Category < Audit::Rollback::Adapters::MasterRecord
  ALLOCATION_TYPES = %w[CategoryTransaction BudgetCategory].freeze
  ALLOCATION_FOREIGN_KEY = "category_id"
  BUDGET_ALLOCATION_TYPE = "BudgetCategory"
  NAME_ATTRIBUTE = "category_name"
  RECALCULATIONS = %w[category_transaction_totals cash_balance].freeze

  def recalculations
    RECALCULATIONS
  end
end
