# frozen_string_literal: true

class AddAppliedAtToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :applied_at, :datetime
    add_index :messages, :applied_at
  end
end
