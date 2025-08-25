# frozen_string_literal: true

class ConversationsController < ApplicationController
  include TabsConcern

  before_action :set_tabs, only: :index

  def index
    @conversations = Conversation.where("sender_id = :user_id OR recipient_id = :user_id", user_id: current_user.id)

    render Views::Conversations::Index.new(conversations: @conversations)
  end

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(created_at: :asc)

    render Views::Conversations::Show.new(conversation: @conversation)
  end

  def create
    @conversation = if Conversation.between(params[:sender_id], params[:recipient_id]).exists?
                      Conversation.between(params[:sender_id], params[:recipient_id]).first
                    else
                      Conversation.create!(conversation_params)
                    end

    redirect_to @conversation
  end

  private

  def conversation_params
    params.permit(:sender_id, :recipient_id)
  end
end
