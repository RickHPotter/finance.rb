# frozen_string_literal: true

class AddContextToInvestments < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"

    has_many :contexts, class_name: "AddContextToInvestments::MigrationContext", foreign_key: :user_id
    has_many :investments, class_name: "AddContextToInvestments::MigrationInvestment", foreign_key: :user_id
  end

  class MigrationContext < ApplicationRecord
    self.table_name = "contexts"

    belongs_to :user, class_name: "AddContextToInvestments::MigrationUser"
  end

  class MigrationInvestment < ApplicationRecord
    self.table_name = "investments"

    belongs_to :user, class_name: "AddContextToInvestments::MigrationUser"
  end

  def up
    add_reference :investments, :context, foreign_key: true

    MigrationInvestment.reset_column_information

    MigrationUser.find_each do |user|
      main_context =
        user.contexts.find_by(main: true) ||
        user.contexts.find_by(name: "Main")&.tap { |context| context.update_columns(main: true) } ||
        user.contexts.create!(name: "Main", main: true)

      user.investments.where(context_id: nil).update_all(context_id: main_context.id)
    end

    change_column_null :investments, :context_id, false
  end

  def down
    remove_reference :investments, :context, foreign_key: true
  end
end
