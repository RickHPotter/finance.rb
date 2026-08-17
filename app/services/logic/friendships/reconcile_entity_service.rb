# frozen_string_literal: true

module Logic
  module Friendships
    class ReconcileEntityService
      def self.call(friendship:)
        return unless friendship.accepted_state?

        [
          { owner: friendship.user, friend: friendship.friend },
          { owner: friendship.friend, friend: friendship.user }
        ].each do |pair|
          owner = pair[:owner]
          friend = pair[:friend]

          entity = owner.entities.find_by(friendship_id: friendship.id)

          next if entity

          owner.entities.create!(
            friendship_id: friendship.id,
            entity_name: friend.profile&.display_name || "Friend",
            built_in: false
          )
        end
      end
    end
  end
end
