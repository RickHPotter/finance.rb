# frozen_string_literal: true

class FriendshipsController < ApplicationController
  include TabsConcern

  before_action :set_basic_tabs

  def index
    @friendships = Friendship.where(user: current_user)
                             .or(Friendship.where(friend: current_user))
                             .includes(user: :profile, friend: :profile)
    render Views::Friendships::Index.new(friendships: @friendships, current_user: current_user)
  end

  def create
    friend = User.find_by(public_id: params[:friend_public_id]) || User.find_by(email: params[:friend_public_id])

    if friend.nil?
      return redirect_back fallback_location: friendships_path, status: :see_other, alert: I18n.t("friendships.alerts.user_not_found")
    elsif friend == current_user
      return redirect_back fallback_location: friendships_path, status: :see_other, alert: I18n.t("friendships.alerts.cannot_friend_self")
    end

    friendship = Friendship.new(user: current_user, friend: friend, state: "pending")

    if friendship.save
      redirect_back fallback_location: friendships_path, status: :see_other, notice: I18n.t("friendships.notices.request_sent")
    else
      redirect_back fallback_location: friendships_path, status: :see_other, alert: I18n.t("friendships.alerts.request_failed")
    end
  end

  def update
    friendship = Friendship.where(user: current_user).or(Friendship.where(friend: current_user)).find_by!(public_id: params[:public_id])

    handle_state_update(friendship) if params[:state].present?

    if params[:friendship].present?
      handle_policy_update(friendship)
      respond_to do |format|
        format.turbo_stream do
          @friendship = friendship
          render "friendships/update"
        end
        format.html { redirect_back fallback_location: friendships_path, status: :see_other }
      end
    else
      redirect_back fallback_location: friendships_path, status: :see_other
    end
  end

  def destroy
    friendship = Friendship.where(user: current_user).or(Friendship.where(friend: current_user)).find_by!(public_id: params[:public_id])

    if friendship.pending_state?
      if friendship.user != current_user
        return redirect_back fallback_location: friendships_path, status: :see_other, alert: I18n.t("friendships.alerts.cannot_cancel")
      end

      friendship.update!(state: "removed")
      notice = I18n.t("friendships.notices.cancelled")

    else
      friendship.update!(state: "removed")
      notice = I18n.t("friendships.notices.removed")
    end

    redirect_back fallback_location: friendships_path, status: :see_other, notice: notice
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
        flash[:notice] = I18n.t("friendships.notices.request_accepted")
      elsif params[:state] == "rejected"
        friendship.update!(state: "rejected")
        flash[:notice] = I18n.t("friendships.notices.request_rejected")
      end
    end

    return unless params[:state] == "blocked"

    friendship.update!(state: "blocked")
    flash[:notice] = I18n.t("friendships.notices.user_blocked")
  end

  def handle_policy_update(friendship)
    return unless friendship.accepted_state?

    friendship.update!(params.require(:friendship).permit(:auto_accept_actionable_messages))
    flash[:notice] = I18n.t("friendships.notices.policy_updated")
  end
end
