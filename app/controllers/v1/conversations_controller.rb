# frozen_string_literal: true

class V1::ConversationsController < V1::ApplicationController
  include V1::TabsConcern

  before_action :set_tabs, only: %i[index show]

  def index
    @conversations = current_user.conversations

    render Views::V1::Conversations::Index.new(conversations: @conversations)
  end

  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(:created_at)
    @messages.unread.where.not(user_id: current_user.id).update_all(read_at: Time.current)

    respond_to do |format|
      format.html do
        render Views::V1::Conversations::Show.new(conversation: @conversation)
      end

      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :conversation)
      end
    end
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
