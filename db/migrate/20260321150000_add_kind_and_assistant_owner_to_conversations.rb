# frozen_string_literal: true

class AddKindAndAssistantOwnerToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :kind, :string, null: false, default: "human"
    add_reference :conversations, :assistant_owner, foreign_key: { to_table: :users }
    add_index :conversations, %i[kind assistant_owner_id], name: "index_conversations_on_kind_and_assistant_owner_id"
  end
end
