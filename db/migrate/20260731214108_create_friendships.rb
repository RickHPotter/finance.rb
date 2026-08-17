# frozen_string_literal: true

class CreateFriendships < ActiveRecord::Migration[8.1]
  def change
    create_table :friendships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :friend, null: false, foreign_key: { to_table: :users }
      t.string :state, null: false, default: "pending"
      t.string :public_id, null: false

      t.jsonb :policies, default: {}, null: false

      t.timestamps
    end

    add_index :friendships,
              "LEAST(user_id, friend_id), GREATEST(user_id, friend_id)",
              unique: true,
              name: "index_friendships_on_user_and_friend_canonical"

    add_index :friendships, :public_id, unique: true

    add_column :users, :public_id, :string

    up_only do
      User.find_each do |user|
        user.update_column(:public_id, SecureRandom.uuid)
      end
    end

    change_column_null :users, :public_id, false
    add_index :users, :public_id, unique: true

    up_only do
      Entity.where.not(entity_user_id: nil).find_each do |entity|
        next if entity.user_id == entity.entity_user_id # Prevent self-friending if data is corrupted

        # Determine the canonical pair to avoid duplicate key errors if both added each other
        user_1 = [ entity.user_id, entity.entity_user_id ].min
        user_2 = [ entity.user_id, entity.entity_user_id ].max

        next if Friendship.where(user_id: user_1, friend_id: user_2).or(Friendship.where(user_id: user_2, friend_id: user_1)).exists?

        Friendship.create!(
          user_id: entity.user_id,
          friend_id: entity.entity_user_id,
          state: "accepted",
          public_id: SecureRandom.uuid
        )
      end
    end
  end
end
