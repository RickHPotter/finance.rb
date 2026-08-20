# frozen_string_literal: true

class CreateMessageActions < ActiveRecord::Migration[8.1]
  ACTIONS = %w[apply acknowledge reject revert].freeze
  INITIATORS = %w[manual automatic system].freeze
  OUTCOMES = %w[succeeded failed denied idempotent].freeze
  STATES = %w[pending accepted rejected expired failed unavailable reverted].freeze
  ERROR_CODES = %w[
    unavailable friendship_unavailable wrong_recipient wrong_context superseded invalid_payload unsupported_action
    local_reference_unavailable local_reference_changed wrong_target unsafe_destroy paid_history state_unavailable
    validation_failed persistence_failed
  ].freeze

  def up
    create_table :message_actions do |t|
      t.references :message, null: false, foreign_key: { on_delete: :restrict }
      t.references :conversation, null: false, foreign_key: { on_delete: :restrict }
      t.references :friendship, null: false, foreign_key: { on_delete: :restrict }
      t.references :actor, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :friend, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :recipient_context, null: false, foreign_key: { to_table: :contexts, on_delete: :restrict }
      t.references :audit_operation, type: :uuid, foreign_key: { on_delete: :restrict }
      t.uuid :scenario_key
      t.string :action, null: false
      t.string :initiator, null: false
      t.string :outcome, null: false
      t.string :resulting_state, null: false
      t.string :error_code
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_message_action_indexes
    add_message_action_constraints
    add_append_only_trigger
  end

  def down
    execute "DROP TRIGGER IF EXISTS message_actions_append_only ON message_actions"
    execute "DROP FUNCTION IF EXISTS prevent_message_action_mutation()"
    drop_table :message_actions
  end

  private

  def add_message_action_indexes
    add_index :message_actions, %i[message_id action], unique: true, where: "outcome = 'succeeded'", name: "index_message_actions_on_successful_effect"
    add_index :message_actions, %i[conversation_id created_at]
    add_index :message_actions, %i[actor_id created_at]
    add_index :message_actions, %i[recipient_context_id created_at]
  end

  def add_message_action_constraints
    add_check_constraint :message_actions, "action IN (#{quoted_values(ACTIONS)})", name: "message_actions_action"
    add_check_constraint :message_actions, "initiator IN (#{quoted_values(INITIATORS)})", name: "message_actions_initiator"
    add_check_constraint :message_actions, "outcome IN (#{quoted_values(OUTCOMES)})", name: "message_actions_outcome"
    add_check_constraint :message_actions, "resulting_state IN (#{quoted_values(STATES)})", name: "message_actions_resulting_state"
    add_check_constraint :message_actions, "error_code IS NULL OR error_code IN (#{quoted_values(ERROR_CODES)})", name: "message_actions_error_code"
    add_check_constraint :message_actions, "octet_length(metadata::text) <= 16384", name: "message_actions_metadata_size"
  end

  def add_append_only_trigger
    execute <<~SQL
      CREATE FUNCTION prevent_message_action_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'message_actions is append-only'
          USING ERRCODE = 'integrity_constraint_violation';
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER message_actions_append_only
      BEFORE UPDATE OR DELETE ON message_actions
      FOR EACH ROW EXECUTE FUNCTION prevent_message_action_mutation();
    SQL
  end

  def quoted_values(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
