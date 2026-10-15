# frozen_string_literal: true

class AddSubscriptionCategoryFamilies < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationProfile < ActiveRecord::Base
    self.table_name = "user_profiles"
  end

  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  def up
    MigrationUser.find_each do |user|
      reconcile_salary!(user)
      reconcile_category!(user, "OTHER")
      reconcile_category!(user, "OTHER INCOME")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot distinguish newly created built-ins from pre-existing user categories"
  end

  private

  def reconcile_salary!(user)
    candidates = MigrationCategory.where(user_id: user.id, parent_category_id: nil, category_name: %w[SALARY SALARIO]).to_a
    raise "User #{user.id} has both SALARY and SALARIO categories; resolve manually" if candidates.size > 1

    category_name = MigrationProfile.find_by(user_id: user.id)&.locale == "pt-BR" ? "SALARIO" : "SALARY"
    reconcile_category!(user, candidates.first&.category_name || category_name)
  end

  def reconcile_category!(user, category_name)
    category = MigrationCategory.find_or_initialize_by(user_id: user.id, parent_category_id: nil, category_name:)
    raise "User #{user.id} has inactive #{category_name}; resolve manually" if category.persisted? && !category.active?

    category.built_in = true
    category.save! if category.new_record? || category.changed?
  end
end
