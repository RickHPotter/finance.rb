# frozen_string_literal: true

module Logic
  module Messages
    class Respond < ActionBase
      SUPPORTED_ACTIONS = %i[acknowledge reject].freeze

      attr_reader :action

      def initialize(message:, actor:, context:, action:, initiator: :manual)
        super(message:, actor:, context:, initiator:)
        @action = action.to_sym
      end

      def call
        raise ArgumentError, "Unsupported message response: #{action}" unless action.in?(SUPPORTED_ACTIONS)

        with_conversation_lock do
          message.with_lock do
            return idempotent_result(action) if completed?

            failure_code = identity_failure_code || response_failure_code
            return denied_result(action, failure_code) if failure_code

            apply_response!
          end
        end
      end

      private

      def completed?
        successful_action(action).present? || (action == :reject && message.workflow_state == "rejected")
      end

      def response_failure_code
        return acknowledge_failure_code if action == :acknowledge
        return unless message.workflow_state != "pending"

        :state_unavailable
      end

      def acknowledge_failure_code
        return if message.paid_state_sync_message? && message.workflow_state == "pending"
        return if message.auto_applied? && message.workflow_state == "accepted"

        :state_unavailable
      end

      def apply_response!
        Transition.call(message, action)
        event = record_action!(action:, outcome: :succeeded)
        result(:succeeded, message_action: event)
      rescue Transition::InvalidTransition
        denied_result(action, :state_unavailable)
      end
    end
  end
end
