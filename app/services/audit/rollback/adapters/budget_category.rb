# frozen_string_literal: true

class Audit::Rollback::Adapters::BudgetCategory < Audit::Rollback::Adapters::BudgetAllocation
  ALLOCATION_FOREIGN_KEY = "category_id"
end
