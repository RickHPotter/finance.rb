# frozen_string_literal: true

class EnforceCanonicalConversationContract < ActiveRecord::Migration[8.1]
  CONVERSATION_KINDS = %w[human assistant].freeze
  MESSAGE_KINDS = %w[human transaction_notification transaction_destroy_notification paid_state_sync].freeze
  ACTION_STATES = %w[pending accepted rejected expired failed unavailable reverted].freeze

  def up
    change_column_null :messages, :kind, false

    add_check_constraint :conversations, "kind IN (#{quoted_values(CONVERSATION_KINDS)})", name: "conversations_kind"
    add_check_constraint :messages, "kind IN (#{quoted_values(MESSAGE_KINDS)})", name: "messages_kind"
    add_check_constraint :messages,
                         "action_state IS NULL OR action_state IN (#{quoted_values(ACTION_STATES)})",
                         name: "messages_action_state"
    add_check_constraint :messages,
                         "(kind = 'human' AND action_state IS NULL) OR (kind <> 'human' AND action_state IS NOT NULL)",
                         name: "messages_kind_action_state"

    create_canonical_participant_guard!
  end

  def down
    execute "DROP TRIGGER IF EXISTS conversation_participants_canonical_pair ON conversation_participants"
    execute "DROP TRIGGER IF EXISTS conversations_canonical_participants ON conversations"
    execute "DROP FUNCTION IF EXISTS enforce_canonical_conversation_participants()"

    remove_check_constraint :messages, name: "messages_kind_action_state"
    remove_check_constraint :messages, name: "messages_action_state"
    remove_check_constraint :messages, name: "messages_kind"
    remove_check_constraint :conversations, name: "conversations_kind"
    change_column_null :messages, :kind, true
  end

  private

  def create_canonical_participant_guard! # rubocop:disable Metrics/MethodLength
    execute <<~SQL
      CREATE FUNCTION enforce_canonical_conversation_participants()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        conversation_key bigint;
        conversation_keys bigint[];
        participant_count integer;
        participant_user_ids bigint[];
        expected_user_ids bigint[];
      BEGIN
        IF TG_TABLE_NAME = 'conversations' THEN
          conversation_keys := ARRAY[NEW.id];
        ELSIF TG_OP = 'DELETE' THEN
          conversation_keys := ARRAY[OLD.conversation_id];
        ELSIF TG_OP = 'UPDATE' AND OLD.conversation_id <> NEW.conversation_id THEN
          conversation_keys := ARRAY[OLD.conversation_id, NEW.conversation_id];
        ELSE
          conversation_keys := ARRAY[NEW.conversation_id];
        END IF;

        FOREACH conversation_key IN ARRAY conversation_keys LOOP
          SELECT COUNT(*), ARRAY_AGG(user_id ORDER BY user_id)
          INTO participant_count, participant_user_ids
          FROM conversation_participants
          WHERE conversation_id = conversation_key;

          SELECT ARRAY[LEAST(friendships.user_id, friendships.friend_id), GREATEST(friendships.user_id, friendships.friend_id)]::bigint[]
          INTO expected_user_ids
          FROM conversations
          JOIN friendships ON friendships.id = conversations.friendship_id
          WHERE conversations.id = conversation_key;

          IF expected_user_ids IS NOT NULL AND (participant_count <> 2 OR participant_user_ids <> expected_user_ids) THEN
            RAISE EXCEPTION 'conversation % must contain exactly its friendship participants', conversation_key
              USING ERRCODE = 'check_violation';
          END IF;
        END LOOP;

        RETURN NULL;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE CONSTRAINT TRIGGER conversations_canonical_participants
      AFTER INSERT OR UPDATE ON conversations
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION enforce_canonical_conversation_participants();
    SQL

    execute <<~SQL
      CREATE CONSTRAINT TRIGGER conversation_participants_canonical_pair
      AFTER INSERT OR UPDATE OR DELETE ON conversation_participants
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION enforce_canonical_conversation_participants();
    SQL
  end

  def quoted_values(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
