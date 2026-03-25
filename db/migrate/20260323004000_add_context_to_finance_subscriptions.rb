# frozen_string_literal: true

class AddContextToFinanceSubscriptions < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"

    has_many :contexts, class_name: "AddContextToFinanceSubscriptions::MigrationContext", foreign_key: :user_id
    has_many :subscriptions, class_name: "AddContextToFinanceSubscriptions::MigrationSubscription", foreign_key: :user_id
  end

  class MigrationContext < ApplicationRecord
    self.table_name = "contexts"

    belongs_to :user, class_name: "AddContextToFinanceSubscriptions::MigrationUser"
  end

  class MigrationSubscription < ApplicationRecord
    self.table_name = "finance_subscriptions"

    belongs_to :user, class_name: "AddContextToFinanceSubscriptions::MigrationUser"
  end

  def up
    add_reference :finance_subscriptions, :context, foreign_key: { to_table: :contexts }

    MigrationSubscription.reset_column_information

    MigrationUser.find_each do |user|
      main_context =
        user.contexts.find_by(main: true) ||
        user.contexts.find_by(name: "Main")&.tap { |context| context.update_columns(main: true) } ||
        user.contexts.create!(name: "Main", main: true)

      user.subscriptions.where(context_id: nil).update_all(context_id: main_context.id)
    end

    change_column_null :finance_subscriptions, :context_id, false
  end

  def down
    remove_reference :finance_subscriptions, :context, foreign_key: { to_table: :contexts }
  end
end
