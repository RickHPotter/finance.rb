# frozen_string_literal: true

class AddStateToConversationParticipants < ActiveRecord::Migration[8.1]
  def up
    add_column :conversation_participants, :archived_at, :datetime
    add_column :conversation_participants, :muted_at, :datetime
    add_reference :conversation_participants,
                  :last_read_message,
                  foreign_key: { to_table: :messages, on_delete: :nullify }

    execute <<~SQL.squish
      UPDATE conversation_participants
      SET last_read_message_id = (
        SELECT messages.id
        FROM messages
        WHERE messages.conversation_id = conversation_participants.conversation_id
          AND messages.user_id <> conversation_participants.user_id
          AND messages.read_at IS NOT NULL
        ORDER BY messages.id DESC
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1
        FROM messages
        WHERE messages.conversation_id = conversation_participants.conversation_id
          AND messages.user_id <> conversation_participants.user_id
          AND messages.read_at IS NOT NULL
      )
    SQL
  end

  def down
    remove_reference :conversation_participants, :last_read_message
    remove_column :conversation_participants, :muted_at
    remove_column :conversation_participants, :archived_at
  end
end
