# frozen_string_literal: true

class Audit::Rollback::Adapters::CategoryTransaction < Audit::Rollback::Adapters::Allocation
  ALLOCATION_FOREIGN_KEY = "category_id"
  CATEGORY_RECALCULATIONS = %w[category_transaction_totals cash_balance].freeze

  def recalculations
    CATEGORY_RECALCULATIONS
  end
end
