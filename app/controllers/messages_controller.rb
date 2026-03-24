# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = current_user.conversations.for_scenario(current_context.scenario_key).find(params[:conversation_id])
    @message = @conversation.messages.build(message_params)
    @message.user = current_user
    @message.save

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation }
    end
  end

  private

  def message_params
    params.require(:message).permit(:body)
  end
end
