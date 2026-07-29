# frozen_string_literal: true

class Audit::Rollback::Adapters::BudgetEntity < Audit::Rollback::Adapters::BudgetAllocation
  ALLOCATION_FOREIGN_KEY = "entity_id"
end
