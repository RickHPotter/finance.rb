# frozen_string_literal: true

class AddContextToCardTransactions < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"

    has_many :contexts, class_name: "AddContextToCardTransactions::MigrationContext", foreign_key: :user_id
    has_many :card_transactions, class_name: "AddContextToCardTransactions::MigrationCardTransaction", foreign_key: :user_id
  end

  class MigrationContext < ApplicationRecord
    self.table_name = "contexts"

    belongs_to :user, class_name: "AddContextToCardTransactions::MigrationUser"
  end

  class MigrationCardTransaction < ApplicationRecord
    self.table_name = "card_transactions"

    belongs_to :user, class_name: "AddContextToCardTransactions::MigrationUser"
  end

  def up
    add_reference :card_transactions, :context, foreign_key: true

    MigrationCardTransaction.reset_column_information

    MigrationUser.find_each do |user|
      main_context =
        user.contexts.find_by(main: true) ||
        user.contexts.find_by(name: "Main")&.tap { |context| context.update_columns(main: true) } ||
        user.contexts.create!(name: "Main", main: true)

      user.card_transactions.where(context_id: nil).update_all(context_id: main_context.id)
    end

    change_column_null :card_transactions, :context_id, false
  end

  def down
    remove_reference :card_transactions, :context, foreign_key: true
  end
end
