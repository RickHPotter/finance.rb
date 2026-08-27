# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = find_conversation
    with_conversation_access do
      @message = @conversation.messages.build(message_params)
      @message.user = current_user
      @message.save
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation, status: :see_other }
    end
  end

  def apply
    @conversation = find_conversation
    @message = @conversation.messages.find(params[:id])

    with_conversation_access do
      @action_result = Logic::Messages::Respond.new(
        message: @message,
        actor: current_user,
        context: current_context,
        action: :acknowledge
      ).call
    end

    respond_with_action_result
  end

  def reject
    @conversation = find_conversation
    @message = @conversation.messages.find(params[:id])
    with_conversation_access do
      @action_result = Logic::Messages::Respond.new(
        message: @message,
        actor: current_user,
        context: current_context,
        action: :reject
      ).call
    end

    respond_with_action_result
  end

  def revert
    @conversation = find_conversation
    @message = @conversation.messages.find(params[:id])

    result = with_conversation_access do
      Logic::Friendships::RevertAutoApplyService.new(
        message: @message, actor: current_user, context: current_context
      ).call
    end

    respond_to do |format|
      format.turbo_stream
      format.html do
        target = conversation_path(@conversation, message_filter: params[:message_filter], message_side: params[:message_side])
        if result.reverted?
          redirect_to target, notice: I18n.t("messages.revert.success"), status: :see_other
        else
          redirect_back fallback_location: target, alert: I18n.t("messages.revert.#{result.failure_reason}"), status: :see_other
        end
      end
    end
  end

  private

  def with_conversation_access(&)
    Logic::Conversations::Policy.new(
      conversation: @conversation,
      actor: current_user,
      context: current_context
    ).with_access(&)
  end

  def respond_with_action_result
    target = conversation_path(@conversation, message_filter: params[:message_filter], message_side: params[:message_side])

    respond_to do |format|
      format.turbo_stream { render :apply }
      format.html do
        if @action_result.applied?
          redirect_to target, status: :see_other
        else
          redirect_to target, alert: I18n.t("messages.actions.errors.#{@action_result.error_code}"), status: :see_other
        end
      end
    end
  end

  def audit_operation_source
    action_name.in?(%w[apply reject revert]) ? :actionable_message : super
  end

  def audit_parent_operation_id
    return super unless action_name.in?(%w[apply reject revert])

    conversation = find_conversation
    conversation.messages.find(params[:id]).audit_operation_id
  end

  def message_params
    params.require(:message).permit(:body)
  end

  def find_conversation
    Logic::Conversations::Policy.scope(user: current_user, context: current_context)
                                .find_by!(public_id: params[:conversation_public_id])
  end
end
