# frozen_string_literal: true

class ConversationsController < ApplicationController
  include TabsConcern

  before_action :set_conversation_tabs, only: %i[index new show]

  def index
    @active_filter = conversation_filter
    page = Logic::Conversations::Page.call(
      scope: filtered_conversations.preload(:conversation_participants, users: { profile: { avatar_attachment: :blob } }),
      cursor: params[:cursor]
    )
    @conversations = page.records

    render Views::Conversations::Index.new(
      conversations: @conversations,
      active_filter: @active_filter,
      page_cursor: params[:cursor],
      next_cursor: page.next_cursor
    )
  end

  def new
    @friendships = available_friendships
    render Views::Conversations::New.new(friendships: @friendships)
  end

  def show
    @conversation = accessible_conversations.preload(users: { profile: { avatar_attachment: :blob } }).find_by!(public_id: params[:public_id])
    conversation_policy(@conversation).with_access do
      prepare_conversation_show
    end
  end

  def create
    friendship = current_user_friendships.find_by!(public_id: params.require(:friendship_public_id))
    @conversation = Logic::Conversations::Resolve.call(
      actor: current_user,
      friendship:,
      kind: :human,
      scenario_key: current_context.scenario_key
    )

    redirect_to @conversation, status: :see_other
  rescue Logic::Conversations::Resolve::UnavailableError
    head :not_found
  end

  def archive
    update_participant_state!({ archived_at: Time.current }, destination: conversations_path)
  end

  def unarchive
    update_participant_state!({ archived_at: nil }, destination: conversation_path(state_conversation))
  end

  def mute
    update_participant_state!({ muted_at: Time.current }, destination: conversation_path(state_conversation))
  end

  def unmute
    update_participant_state!({ muted_at: nil }, destination: conversation_path(state_conversation))
  end

  private

  def set_conversation_tabs
    set_tabs(active_menu: :profile, active_sub_menu: :conversation)
  end

  def filtered_conversations
    scope = participant_filtered_conversations

    case conversation_filter
    when "unread"
      scope = scope.with_unread_for(current_user)
    when "human"
      scope = scope.human
    when "assistant"
      scope = scope.assistant
    end

    scope
  end

  def scoped_conversations
    accessible_conversations.active_for(current_user)
  end

  def participant_filtered_conversations
    case conversation_filter
    when "archived"
      accessible_conversations.archived_for(current_user)
    when "muted"
      accessible_conversations.active_for(current_user).muted_for(current_user)
    else
      scoped_conversations
    end
  end

  def accessible_conversations
    Logic::Conversations::Policy.scope(user: current_user, context: current_context)
  end

  def conversation_filter
    params[:filter].presence_in(%w[active unread human assistant archived muted]) || "active"
  end

  def current_user_friendships
    Friendship.where(user: current_user).or(Friendship.where(friend: current_user))
  end

  def available_friendships
    friendships = current_user_friendships
                  .accepted_state
                  .includes(user: { profile: { avatar_attachment: :blob } }, friend: { profile: { avatar_attachment: :blob } })
                  .select do |friendship|
      friend = friendship.user_id == current_user.id ? friendship.friend : friendship.user
      context_available_for?(friend)
    end

    friendships.sort_by do |friendship|
      friend = friendship.user_id == current_user.id ? friendship.friend : friendship.user
      [ (friend.display_name.presence || friend.email).downcase, friendship.id ]
    end
  end

  def context_available_for?(friend)
    if current_context.main?
      friend.contexts.active.exists?(main: true)
    else
      friend.contexts.active.exists?(main: false, scenario_key: current_context.scenario_key)
    end
  end

  def state_conversation
    @state_conversation ||= accessible_conversations.find_by!(public_id: params[:public_id])
  end

  def update_participant_state!(attributes, destination:)
    conversation_policy(state_conversation).with_access do
      state_conversation.participant_for!(current_user).update!(attributes)
    end
    redirect_to destination, status: :see_other
  end

  def conversation_policy(conversation)
    Logic::Conversations::Policy.new(conversation:, actor: current_user, context: current_context)
  end

  def prepare_conversation_show
    @active_message_filter = conversation_message_filter
    @active_message_sides = conversation_message_sides
    scope, selector = filtered_messages(@conversation)
    page = Logic::Messages::Page.call(scope:, selector:, cursor: params[:message_cursor])
    @messages = page.records
    @newest_page_message = @conversation.messages.latest.reorder(created_at: :desc, id: :desc).first if params[:message_cursor].blank?
    mark_visible_page_read if params[:message_cursor].blank?

    render_conversation_show(page)
  end

  def mark_visible_page_read
    read_at = Time.current
    @conversation.messages.unread.where.not(user_id: current_user.id).where(auto_applied: false).find_each do |message|
      message.update!(read_at:)
    end
    @conversation.participant_for!(current_user).advance_read_cursor_to!(@newest_page_message)
  end

  def render_conversation_show(page)
    render Views::Conversations::Show.new(
      conversation: @conversation,
      messages: @messages,
      active_message_filter: @active_message_filter,
      active_message_sides: @active_message_sides,
      message_page_cursor: params[:message_cursor],
      next_message_cursor: page.next_cursor,
      streamables: Logic::Conversations::Stream.for(conversation: @conversation, actor: current_user, context: current_context)
    )
  end

  def filtered_messages(conversation)
    scope = conversation.messages.includes(:user)
    return [ scope, nil ] if conversation.human?

    if conversation_message_sides.one?
      scope = conversation_message_sides.first == "mine" ? scope.where(user_id: current_user.id) : scope.where.not(user_id: current_user.id)
    end

    selector = lambda do |message|
      next true if conversation_message_filter == "all"
      next false if message.workflow_state == "expired"

      message.actionable_for?(context: current_context)
    end

    [ scope, selector ]
  end

  def conversation_message_filter
    return "all" if @conversation&.human?

    params[:message_filter].presence_in(%w[pending all]) || "pending"
  end

  def conversation_message_sides
    return %w[mine theirs] if @conversation&.human?

    requested_sides = Array(params[:message_side]).presence || %w[mine theirs]
    requested_sides & %w[mine theirs]
  end
end
