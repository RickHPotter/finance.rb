# frozen_string_literal: true

class AddCanonicalIdentityToConversations < ActiveRecord::Migration[8.1]
  def up
    add_reference :conversations, :friendship, foreign_key: true
    add_column :conversations, :public_id, :uuid, null: false, default: -> { "gen_random_uuid()" }

    collapse_duplicate_participants!

    add_index :conversations, :public_id, unique: true
    add_index :conversation_participants, %i[conversation_id user_id], unique: true, name: "index_conversation_participants_on_membership"
    add_index :conversations,
              %i[friendship_id kind],
              unique: true,
              where: "friendship_id IS NOT NULL AND scenario_key IS NULL",
              name: "index_conversations_on_main_canonical_identity"
    add_index :conversations,
              %i[friendship_id kind scenario_key],
              unique: true,
              where: "friendship_id IS NOT NULL AND scenario_key IS NOT NULL",
              name: "index_conversations_on_scenario_canonical_identity"
  end

  def down
    remove_index :conversations, name: "index_conversations_on_scenario_canonical_identity"
    remove_index :conversations, name: "index_conversations_on_main_canonical_identity"
    remove_index :conversation_participants, name: "index_conversation_participants_on_membership"
    remove_index :conversations, :public_id
    remove_column :conversations, :public_id
    remove_reference :conversations, :friendship
  end

  private

  def collapse_duplicate_participants!
    execute <<~SQL.squish
      DELETE FROM conversation_participants duplicate
      USING conversation_participants canonical
      WHERE duplicate.conversation_id = canonical.conversation_id
        AND duplicate.user_id = canonical.user_id
        AND duplicate.id > canonical.id
    SQL
  end
end
