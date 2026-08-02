# frozen_string_literal: true

class FriendshipsController < ApplicationController
  include TabsConcern

  before_action :set_basic_tabs

  def index
    @friendships = Friendship.where(user: current_user).or(Friendship.where(friend: current_user))
    render Views::Friendships::Index.new(friendships: @friendships, current_user: current_user)
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

    handle_state_update(friendship) if params[:state].present?
    handle_policy_update(friendship) if params[:friendship].present?

    redirect_back fallback_location: friendships_path
  end

  def destroy
    friendship = Friendship.where(user: current_user).or(Friendship.where(friend: current_user)).find_by!(public_id: params[:public_id])

    friendship.update!(state: "removed")

    redirect_back fallback_location: friendships_path, notice: "Friendship removed."
  end

  private

  def set_basic_tabs
    set_tabs(active_menu: :profile, active_sub_menu: :friendship)
  end

  def handle_state_update(friendship)
    if friendship.friend == current_user && friendship.pending_state?
      if params[:state] == "accepted"
        friendship.update!(state: "accepted")
        Logic::Friendships::ReconcileEntityService.call(friendship:)
        flash[:notice] = "Friend request accepted."
      elsif params[:state] == "rejected"
        friendship.update!(state: "rejected")
        flash[:notice] = "Friend request rejected."
      end
    end

    return unless params[:state] == "blocked"

    friendship.update!(state: "blocked")
    flash[:notice] = "User blocked."
  end

  def handle_policy_update(friendship)
    return unless friendship.accepted_state?

    friendship.update!(params.require(:friendship).permit(:auto_accept_actionable_messages))
    flash[:notice] = "Friendship policy updated."
  end
end
