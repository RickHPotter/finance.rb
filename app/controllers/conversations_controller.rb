# frozen_string_literal: true

class ConversationsController < ApplicationController
  include TabsConcern

  before_action :set_conversation_tabs, only: %i[index show]

  def index
    @active_filter = conversation_filter
    @conversations = filtered_conversations.preload(:users, :messages).sort_by do |conversation|
      [ conversation.human? ? 0 : 1, -(conversation.latest_message&.created_at || conversation.created_at).to_i ]
    end

    render Views::Conversations::Index.new(conversations: @conversations, active_filter: @active_filter)
  end

  def show
    @conversation = scoped_conversations.preload(:users).find(params[:id])
    @active_message_filter = conversation_message_filter
    @active_message_sides = conversation_message_sides
    @messages = filtered_messages(@conversation)
    @conversation.messages.unread.where.not(user_id: current_user.id).update_all(read_at: Time.current)

    respond_to do |format|
      format.html do
        render Views::Conversations::Show.new(
          conversation: @conversation,
          messages: @messages,
          active_message_filter: @active_message_filter,
          active_message_sides: @active_message_sides
        )
      end
      format.turbo_stream
    end
  end

  def create
    @conversation = Conversation.create!(conversation_params.merge(scenario_key: current_context.scenario_key))

    redirect_to @conversation
  end

  private

  def set_conversation_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :conversation)
  end

  def filtered_conversations
    scope = scoped_conversations

    case conversation_filter
    when "unread"
      scope = scope.joins(:messages).merge(Message.unread.where.not(user_id: current_user.id)).distinct
    when "human"
      scope = scope.human
    when "assistant"
      scope = scope.assistant
    end

    scope
  end

  def scoped_conversations
    current_user.conversations.for_scenario(current_context.scenario_key)
  end

  def conversation_filter
    params[:filter].presence_in(%w[unread human assistant]) || "all"
  end

  def conversation_params
    params.permit(conversation_participants_attributes: %i[id user_id _destroy])
  end

  def filtered_messages(conversation)
    scope = conversation.messages.includes(:user).order(:created_at)
    return scope if conversation.human?

    scope.to_a.select do |message|
      next false unless conversation_message_sides.include?(message.assistant_side_for(current_user))
      next true if conversation_message_filter == "all"
      next false if message.superseded_by_id.present?

      message.actionable_for?(context: current_context)
    end
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
