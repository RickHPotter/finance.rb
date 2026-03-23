# frozen_string_literal: true

class AddContextToReferences < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"

    has_many :contexts, class_name: "AddContextToReferences::MigrationContext", foreign_key: :user_id
  end

  class MigrationContext < ApplicationRecord
    self.table_name = "contexts"

    belongs_to :user, class_name: "AddContextToReferences::MigrationUser"
  end

  class MigrationUserCard < ApplicationRecord
    self.table_name = "user_cards"

    belongs_to :user, class_name: "AddContextToReferences::MigrationUser"
  end

  class MigrationReference < ApplicationRecord
    self.table_name = "references"

    belongs_to :user_card, class_name: "AddContextToReferences::MigrationUserCard"
  end

  def up
    add_reference :references, :context, foreign_key: true

    MigrationReference.reset_column_information

    MigrationReference.includes(user_card: :user).find_each do |reference|
      user = reference.user_card.user
      main_context =
        user.contexts.find_by(main: true) ||
        user.contexts.find_by(name: "Main")&.tap { |context| context.update_columns(main: true) } ||
        user.contexts.create!(name: "Main", main: true)

      reference.update_columns(context_id: main_context.id)
    end

    change_column_null :references, :context_id, false
  end

  def down
    remove_reference :references, :context, foreign_key: true
  end
end
