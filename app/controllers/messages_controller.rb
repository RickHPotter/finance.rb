# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = current_user.conversations.for_scenario(current_context.scenario_key).find(params[:conversation_id])
    @message = @conversation.messages.build(message_params)
    @message.user = current_user
    @message.save

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation, status: :see_other }
    end
  end

  def apply
    @conversation = current_user.conversations.for_scenario(current_context.scenario_key).find(params[:conversation_id])
    @message = @conversation.messages.find(params[:id])

    # Slice 9: setting read_at for the OK acknowledge button
    @message.update!(read_at: Time.current) if @message.auto_applied? && @message.read_at.blank?
    @message.update!(applied_at: Time.current) unless @message.applied?

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to conversation_path(@conversation, message_filter: params[:message_filter], message_side: params[:message_side]), status: :see_other
      end
    end
  end

  def revert
    @conversation = current_user.conversations.for_scenario(current_context.scenario_key).find(params[:conversation_id])
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

  def audit_operation_source
    action_name.in?(%w[apply revert]) ? :actionable_message : super
  end

  def audit_parent_operation_id
    return super unless action_name.in?(%w[apply revert])

    conversation = current_user.conversations.for_scenario(current_context.scenario_key).find(params[:conversation_id])
    conversation.messages.find(params[:id]).audit_operation_id
  end

  def message_params
    params.require(:message).permit(:body)
  end
end
