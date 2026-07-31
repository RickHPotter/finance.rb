# frozen_string_literal: true

class AddPoliciesToFriendships < ActiveRecord::Migration[8.1]
  def change
    add_column :friendships, :policies, :jsonb, default: {}, null: false
  end
end
