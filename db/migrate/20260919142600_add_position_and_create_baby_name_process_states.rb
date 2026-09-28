# frozen_string_literal: true

class AddPositionAndCreateBabyNameProcessStates < ActiveRecord::Migration[8.1]
  def change
    add_column :baby_name_decisions, :position, :integer
    add_index :baby_name_decisions, %i[user_id position]

    create_table :baby_name_process_states do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :phase, null: false, default: "phase_1"
      t.boolean :phase_completed, null: false, default: false

      t.timestamps
    end
  end
end
