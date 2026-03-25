# frozen_string_literal: true

class AddContextToCashTransactions < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"

    has_many :contexts, class_name: "AddContextToCashTransactions::MigrationContext", foreign_key: :user_id
    has_many :cash_transactions, class_name: "AddContextToCashTransactions::MigrationCashTransaction", foreign_key: :user_id
  end

  class MigrationContext < ApplicationRecord
    self.table_name = "contexts"

    belongs_to :user, class_name: "AddContextToCashTransactions::MigrationUser"
  end

  class MigrationCashTransaction < ApplicationRecord
    self.table_name = "cash_transactions"

    belongs_to :user, class_name: "AddContextToCashTransactions::MigrationUser"
  end

  def up
    add_reference :cash_transactions, :context, foreign_key: true

    MigrationCashTransaction.reset_column_information

    MigrationUser.find_each do |user|
      main_context =
        user.contexts.find_by(main: true) ||
        user.contexts.find_by(name: "Main")&.tap { |context| context.update_columns(main: true) } ||
        user.contexts.create!(name: "Main", main: true)

      user.cash_transactions.where(context_id: nil).update_all(context_id: main_context.id)
    end

    change_column_null :cash_transactions, :context_id, false
  end

  def down
    remove_reference :cash_transactions, :context, foreign_key: true
  end
end
