# frozen_string_literal: true

class ScopeReferenceUniquenessToContext < ActiveRecord::Migration[8.1]
  def change
    remove_index :references, name: "idx_references_user_card_month_year"

    add_index :references,
              %i[context_id user_card_id month year],
              unique: true,
              name: "idx_references_context_user_card_month_year"

    add_index :references,
              %i[context_id user_card_id reference_date],
              unique: true,
              name: "idx_references_context_user_card_reference_date"
  end
end
