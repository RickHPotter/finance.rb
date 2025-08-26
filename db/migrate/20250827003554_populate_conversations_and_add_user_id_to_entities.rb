# frozen_string_literal: true

class PopulateConversationsAndAddUserIdToEntities < ActiveRecord::Migration[8.0]
  def change
    Conversation.create(sender: User.first, recipient: User.second) if User.count >= 2

    change_table :entities do |t|
      t.references :entity_user, null: true, foreign_key: { to_table: :users }
    end
  end
end
