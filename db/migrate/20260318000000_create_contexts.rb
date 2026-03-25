# frozen_string_literal: true

class CreateContexts < ActiveRecord::Migration[8.1]
  def change
    create_table :contexts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :source_context, foreign_key: { to_table: :contexts }
      t.string :name, null: false
      t.text :description
      t.boolean :main, default: false, null: false
      t.datetime :cloned_at
      t.datetime :archived_at

      t.timestamps
    end

    add_index :contexts, %i[user_id name], unique: true, name: "index_contexts_on_user_and_name"
    add_index :contexts, :user_id, unique: true, where: "main = true", name: "index_contexts_on_user_id_where_main_true"
  end
end
