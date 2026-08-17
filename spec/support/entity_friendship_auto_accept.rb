# frozen_string_literal: true

module EntityFriendshipAutoAccept
  def assign_friendship_if_needed
    super
    friendship.state = "accepted" if friendship&.pending_state?
  end
end

Entity.prepend(EntityFriendshipAutoAccept)
