# frozen_string_literal: true

class ConversationsController < ApplicationController
  include TabsConcern

  before_action :set_tabs, only: %i[index show]

  def index
    @conversations = current_user.conversations

    render Views::Conversations::Index.new(conversations: @conversations)
  end

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(created_at: :asc)
    @messages.unread.where.not(user_id: current_user.id).update_all(read_at: Time.current)

    render Views::Conversations::Show.new(conversation: @conversation)
  end

  def create
    @conversation = Conversation.create!(conversation_params)

    redirect_to @conversation
  end

  private

  def conversation_params
    params.permit(conversation_participants_attributes: %i[id user_id _destroy])
  end
end
