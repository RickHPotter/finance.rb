# frozen_string_literal: true

class AddAutoAppliedAndRevertedAtToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :auto_applied, :boolean, default: false, null: false
    add_column :messages, :reverted_at, :datetime
    add_index :messages, :reverted_at
  end
end
