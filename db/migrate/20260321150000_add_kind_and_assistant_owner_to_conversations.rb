# frozen_string_literal: true

class AddKindAndAssistantOwnerToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :kind, :string, null: false, default: "human"
    add_index :conversations, :kind
  end
end
