# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = find_conversation
    @message = @conversation.messages.build(message_params)
    @message.user = current_user
    @message.save

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation, status: :see_other }
    end
  end

  def apply
    @conversation = find_conversation
    @message = @conversation.messages.find(params[:id])

    @action_result = Logic::Messages::Respond.new(
      message: @message,
      actor: current_user,
      context: current_context,
      action: :acknowledge
    ).call

    respond_with_action_result
  end

  def reject
    @conversation = find_conversation
    @message = @conversation.messages.find(params[:id])
    @action_result = Logic::Messages::Respond.new(
      message: @message,
      actor: current_user,
      context: current_context,
      action: :reject
    ).call

    respond_with_action_result
  end

  def revert
    @conversation = find_conversation
    @message = @conversation.messages.find(params[:id])

    result = Logic::Friendships::RevertAutoApplyService.new(
      message: @message, actor: current_user, context: current_context
    ).call

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
    current_user.conversations
                .joins(:friendship)
                .merge(Friendship.accepted_state)
                .for_scenario(current_context.scenario_key)
                .find_by!(public_id: params[:conversation_public_id])
  end
end
