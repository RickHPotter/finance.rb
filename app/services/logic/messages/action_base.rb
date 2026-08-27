# frozen_string_literal: true

module Logic
  module Messages
    class ActionBase
      attr_reader :message, :actor, :context, :initiator

      def initialize(message:, actor:, context:, initiator:)
        @message = message
        @actor = actor
        @context = context
        @initiator = initiator.to_sym
      end

      private

      def identity_failure_code
        return :wrong_recipient unless recipient&.id == actor&.id

        conversation_policy.failure_code
      end

      def friendship
        @friendship ||= message.conversation.friendship || message.user.friendship_with(recipient)
      end

      def recipient
        @recipient ||= message.conversation.friend_for(message.user)
      end

      def conversation_policy
        @conversation_policy ||= Logic::Conversations::Policy.new(conversation: message.conversation, actor:, context:)
      end

      def with_conversation_lock(&)
        conversation_policy.with_friendship_lock(&)
      end

      def successful_action(action)
        message.message_actions.find_by(action:, outcome: :succeeded)
      end

      def record_action!(action:, outcome:, error_code: nil, audit_operation: nil, metadata: {})
        return if message.workflow_state.blank? || friendship.blank? || actor.blank? || context.blank? || ledger_friend.blank?

        MessageAction.create!(
          message:,
          conversation: message.conversation,
          friendship:,
          actor:,
          friend: ledger_friend,
          recipient_context: context,
          audit_operation:,
          scenario_key: message.conversation.scenario_key,
          action:,
          initiator:,
          outcome:,
          resulting_state: message.workflow_state,
          error_code: error_code&.to_s,
          metadata:
        )
      end

      def ledger_friend
        @ledger_friend ||= message.conversation.friend_for(actor)
      end

      def result(status, message_action: nil, error_code: nil, audit_operation: nil)
        ActionResult.new(status:, message_action:, error_code: error_code&.to_s, audit_operation:)
      end

      def idempotent_result(action, successful = successful_action(action))
        event = record_action!(action:, outcome: :idempotent, audit_operation: successful&.audit_operation)
        result(:idempotent, message_action: event, audit_operation: successful&.audit_operation)
      end

      def denied_result(action, error_code, metadata: {})
        event = record_action!(action:, outcome: :denied, error_code:, metadata:)
        result(:denied, message_action: event, error_code:)
      end
    end
  end
end
