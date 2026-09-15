# frozen_string_literal: true

class CreateBabyNamesAndDecisions < ActiveRecord::Migration[8.1]
  class MigrationBabyName < ActiveRecord::Base
    self.table_name = "baby_names"
  end

  STARTER_NAMES = %w[
    Arthur
    Benjamin
    Caio
    Davi
    Elias
    Gabriel
    Gael
    Heitor
    Hugo
    Joaquim
    Leonardo
    Luca
    Mateo
    Miguel
    Noah
    Rafael
    Samuel
    Theo
    Vicente
    Xavier
  ].freeze

  def up
    create_table :baby_names do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :baby_names, :name, unique: true
    add_index :baby_names, %i[active position]

    create_table :baby_name_decisions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :baby_name, null: false, foreign_key: true
      t.string :choice, null: false

      t.timestamps
    end

    add_index :baby_name_decisions, %i[user_id baby_name_id], unique: true
    add_check_constraint :baby_name_decisions,
                         "choice IN ('rejected', 'accepted', 'later')",
                         name: "baby_name_decisions_choice_check"

    now = Time.current
    MigrationBabyName.insert_all!(
      STARTER_NAMES.each_with_index.map do |name, index|
        { name:, position: index + 1, active: true, created_at: now, updated_at: now }
      end
    )
  end

  def down
    drop_table :baby_name_decisions
    drop_table :baby_names
  end
end
