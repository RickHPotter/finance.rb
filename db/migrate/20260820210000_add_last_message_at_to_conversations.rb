# frozen_string_literal: true

class AddLastMessageAtToConversations < ActiveRecord::Migration[8.1]
  def up
    add_column :conversations, :last_message_at, :datetime

    execute <<~SQL.squish
      UPDATE conversations
      SET last_message_at = COALESCE(
        (SELECT MAX(messages.created_at) FROM messages WHERE messages.conversation_id = conversations.id),
        conversations.created_at
      )
    SQL

    change_column_null :conversations, :last_message_at, false
    add_index :conversations, %i[last_message_at id], order: { last_message_at: :desc, id: :desc }, name: "index_conversations_on_activity"
    add_index :messages, %i[conversation_id created_at id], order: { created_at: :desc, id: :desc }, name: "index_messages_on_conversation_cursor"
  end

  def down
    remove_index :messages, name: "index_messages_on_conversation_cursor"
    remove_index :conversations, name: "index_conversations_on_activity"
    remove_column :conversations, :last_message_at
  end
end
