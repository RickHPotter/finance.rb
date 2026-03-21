# frozen_string_literal: true

class ConversationsController < ApplicationController
  include TabsConcern

  before_action :set_conversation_tabs, only: %i[index show]

  def index
    @active_filter = conversation_filter
    @conversations = filtered_conversations.preload(:assistant_owner, :users, :messages).sort_by do |conversation|
      [ conversation.human? ? 0 : 1, -(conversation.latest_message&.created_at || conversation.created_at).to_i ]
    end

    render Views::Conversations::Index.new(conversations: @conversations, active_filter: @active_filter)
  end

  def show
    @conversation = current_user.conversations.preload(:assistant_owner, :users).find(params[:id])
    @messages = @conversation.messages.order(:created_at)
    @messages.unread.where.not(user_id: current_user.id).update_all(read_at: Time.current)

    respond_to do |format|
      format.html { render Views::Conversations::Show.new(conversation: @conversation, messages: @messages) }
      format.turbo_stream
    end
  end

  def create
    @conversation = Conversation.create!(conversation_params)

    redirect_to @conversation
  end

  private

  def set_conversation_tabs
    set_tabs(active_menu: :basic, active_sub_menu: :conversation)
  end

  def filtered_conversations
    scope = current_user.conversations

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

  def conversation_filter
    params[:filter].presence_in(%w[unread human assistant]) || "all"
  end

  def conversation_params
    params.permit(conversation_participants_attributes: %i[id user_id _destroy])
  end
end
