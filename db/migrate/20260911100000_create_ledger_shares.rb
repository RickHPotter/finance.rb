# frozen_string_literal: true

class CreateLedgerShares < ActiveRecord::Migration[8.1]
  def up
    create_table :ledger_shares do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :context, null: false, foreign_key: true
      t.uuid :public_id, null: false, default: -> { "gen_random_uuid()" }
      t.string :token_digest, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_accessed_at
      t.bigint :access_count, null: false, default: 0
      t.timestamps
    end

    add_index :ledger_shares, :public_id, unique: true
    add_index :ledger_shares, :token_digest, unique: true
    add_index :ledger_shares, %i[entity_id context_id], where: "revoked_at IS NULL", name: "index_active_ledger_shares_on_scope"
    add_check_constraint :ledger_shares, "access_count >= 0", name: "ledger_shares_access_count_nonnegative"
    add_check_constraint :ledger_shares,
                         "token_digest ~ '^[0-9a-f]{64}$'",
                         name: "ledger_shares_token_digest_format"

    create_owner_guard!
  end

  def down
    execute "DROP TRIGGER IF EXISTS ledger_shares_owner_guard ON ledger_shares"
    execute "DROP FUNCTION IF EXISTS enforce_ledger_share_owner()"
    drop_table :ledger_shares
  end

  private

  def create_owner_guard!
    execute <<~SQL
      CREATE FUNCTION enforce_ledger_share_owner()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM entities
          INNER JOIN contexts ON contexts.id = NEW.context_id
          WHERE entities.id = NEW.entity_id
            AND entities.user_id = contexts.user_id
        ) THEN
          RAISE EXCEPTION 'ledger share entity and context must have the same owner'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER ledger_shares_owner_guard
      BEFORE INSERT OR UPDATE OF entity_id, context_id ON ledger_shares
      FOR EACH ROW EXECUTE FUNCTION enforce_ledger_share_owner();
    SQL
  end
end
