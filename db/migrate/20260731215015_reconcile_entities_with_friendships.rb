# frozen_string_literal: true

class ReconcileEntitiesWithFriendships < ActiveRecord::Migration[8.1]
  def up
    add_reference :entities, :friendship, foreign_key: true

    up_only do
      Entity.where.not(entity_user_id: nil).find_each do |entity|
        user_1 = [entity.user_id, entity.entity_user_id].min
        user_2 = [entity.user_id, entity.entity_user_id].max
        
        friendship = Friendship.find_by(user_id: user_1, friend_id: user_2) || 
                     Friendship.find_by(user_id: user_2, friend_id: user_1)
                     
        entity.update_column(:friendship_id, friendship.id) if friendship
      end
    end

    remove_reference :entities, :entity_user
  end

  def down
    add_reference :entities, :entity_user, foreign_key: { to_table: :users }

    down_only do
      Entity.where.not(friendship_id: nil).find_each do |entity|
        friendship = Friendship.find_by(id: entity.friendship_id)
        next unless friendship
        
        target_user_id = friendship.user_id == entity.user_id ? friendship.friend_id : friendship.user_id
        entity.update_column(:entity_user_id, target_user_id)
      end
    end

    remove_reference :entities, :friendship
  end
end
