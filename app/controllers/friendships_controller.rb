# frozen_string_literal: true

class FriendshipsController < ApplicationController
  def index
    @friendships = Friendship.where(user: current_user).or(Friendship.where(friend: current_user))
  end

  def create
    friend = User.find_by(public_id: params[:friend_public_id]) || User.find_by(email: params[:email])

    if friend.nil?
      return redirect_back fallback_location: friendships_path, alert: "User not found."
    elsif friend == current_user
      return redirect_back fallback_location: friendships_path, alert: "You cannot friend yourself."
    end

    friendship = Friendship.new(user: current_user, friend: friend, state: "pending")

    if friendship.save
      redirect_back fallback_location: friendships_path, notice: "Friend request sent."
    else
      redirect_back fallback_location: friendships_path, alert: "Could not send friend request."
    end
  end

  def update
    friendship = Friendship.where(user: current_user).or(Friendship.where(friend: current_user)).find_by!(public_id: params[:public_id])

    # If the user is the recipient of the request (the "friend") and the state is pending, they can accept or reject
    if friendship.friend == current_user && friendship.pending?
      if params[:state] == "accepted"
        friendship.update!(state: "accepted")
        Logic::Friendships::ReconcileEntityService.call(friendship:)
        flash[:notice] = "Friend request accepted."
      elsif params[:state] == "rejected"
        friendship.update!(state: "rejected")
        flash[:notice] = "Friend request rejected."
      end
    end

    # Either user can block
    if params[:state] == "blocked"
      # If blocked, we might want to store who blocked who. But the state is just "blocked".
      # For now, just update the state.
      friendship.update!(state: "blocked")
      flash[:notice] = "User blocked."
    end

    redirect_back fallback_location: friendships_path
  end

  def destroy
    friendship = Friendship.where(user: current_user).or(Friendship.where(friend: current_user)).find_by!(public_id: params[:public_id])

    friendship.update!(state: "removed")

    redirect_back fallback_location: friendships_path, notice: "Friendship removed."
  end
end
