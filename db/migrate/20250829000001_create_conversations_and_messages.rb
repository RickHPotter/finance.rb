# frozen_string_literal: true

class CreateConversationsAndMessages < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:conversations)
      create_table :conversations do |t|
        t.timestamps
      end
    end

    unless table_exists?(:conversation_participants)
      create_table :conversation_participants do |t|
        t.references :conversation, null: false, foreign_key: true, index: true
        t.references :user, null: false, foreign_key: true, index: true
        t.timestamps
      end
    end

    return if table_exists?(:messages)

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :superseded_by, null: true, foreign_key: { to_table: :messages }
      t.references :reference_transactable, polymorphic: true, index: true

      t.text :body
      t.text :headers
      t.datetime :read_at

      t.timestamps
    end
  end
end
