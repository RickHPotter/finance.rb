# frozen_string_literal: true

class CreateHealthCheckRuns < ActiveRecord::Migration[8.1]
  CHECK_KEYS = %w[exchange_trio exchange_return card_exchange_projection misplaced_exchange_intent piggy_bank].freeze
  EXECUTION_STATES = %w[queued running completed unavailable].freeze
  OUTCOMES = %w[healthy warning failing].freeze

  def change
    create_table :health_check_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :context, null: false, foreign_key: true
      t.references :connected_user, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :check_key, null: false
      t.uuid :generation_token, null: false, default: -> { "gen_random_uuid()" }
      t.string :execution_state, null: false, default: "queued"
      t.string :outcome
      t.jsonb :counts, null: false, default: {}
      t.datetime :queued_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :started_at
      t.datetime :finished_at
      t.bigint :duration_ms
      t.string :error_code, limit: 100

      t.timestamps
    end

    add_scope_indexes
    add_contract_constraints
  end

  private

  def add_scope_indexes
    add_index :health_check_runs,
              %i[check_key user_id context_id],
              unique: true,
              where: "connected_user_id IS NULL",
              name: "idx_health_check_runs_unfiltered_scope"
    add_index :health_check_runs,
              %i[check_key user_id context_id connected_user_id],
              unique: true,
              where: "connected_user_id IS NOT NULL",
              name: "idx_health_check_runs_connected_scope"
    add_index :health_check_runs, %i[execution_state updated_at]
  end

  def add_contract_constraints
    add_check_constraint :health_check_runs, "check_key IN (#{quoted_values(CHECK_KEYS)})", name: "health_check_runs_check_key"
    add_check_constraint :health_check_runs, "execution_state IN (#{quoted_values(EXECUTION_STATES)})", name: "health_check_runs_execution_state"
    add_check_constraint :health_check_runs, "outcome IS NULL OR outcome IN (#{quoted_values(OUTCOMES)})", name: "health_check_runs_outcome"
    add_check_constraint :health_check_runs,
                         "(execution_state = 'completed' AND outcome IS NOT NULL) OR (execution_state <> 'completed' AND outcome IS NULL)",
                         name: "health_check_runs_completed_outcome"
    add_check_constraint :health_check_runs, "jsonb_typeof(counts) = 'object'", name: "health_check_runs_counts_object"
    add_check_constraint :health_check_runs, "octet_length(counts::text) <= 4096", name: "health_check_runs_counts_size"
    add_check_constraint :health_check_runs, "duration_ms IS NULL OR duration_ms >= 0", name: "health_check_runs_duration"
  end

  def quoted_values(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
