# frozen_string_literal: true

class AddContextToBudgets < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"

    has_many :contexts, class_name: "AddContextToBudgets::MigrationContext", foreign_key: :user_id
    has_many :budgets, class_name: "AddContextToBudgets::MigrationBudget", foreign_key: :user_id
  end

  class MigrationContext < ApplicationRecord
    self.table_name = "contexts"

    belongs_to :user, class_name: "AddContextToBudgets::MigrationUser"
  end

  class MigrationBudget < ApplicationRecord
    self.table_name = "budgets"

    belongs_to :user, class_name: "AddContextToBudgets::MigrationUser"
  end

  def up
    add_reference :budgets, :context, foreign_key: true

    MigrationBudget.reset_column_information

    MigrationUser.find_each do |user|
      main_context =
        user.contexts.find_by(main: true) ||
        user.contexts.find_by(name: "Main")&.tap { |context| context.update_columns(main: true) } ||
        user.contexts.create!(name: "Main", main: true)

      user.budgets.where(context_id: nil).update_all(context_id: main_context.id)
    end

    change_column_null :budgets, :context_id, false
  end

  def down
    remove_reference :budgets, :context, foreign_key: true
  end
end
