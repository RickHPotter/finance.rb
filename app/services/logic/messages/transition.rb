# frozen_string_literal: true

module Logic
  module Messages
    class Transition
      class InvalidTransition < StandardError
      end

      TRANSITIONS = {
        acknowledge: { pending: :accepted, accepted: :accepted },
        apply: { pending: :accepted, failed: :accepted },
        reject: { pending: :rejected },
        expire: { pending: :expired, failed: :expired, unavailable: :expired },
        fail: { pending: :failed },
        unavailable: { pending: :unavailable, failed: :unavailable },
        revert: { accepted: :reverted }
      }.freeze

      attr_reader :message, :event, :at, :attributes

      def self.call(message, event, at: Time.current, **attributes)
        new(message, event, at:, attributes:).call
      end

      def self.expire_scope!(scope, superseded_by:, at: Time.current)
        scope.find_each do |message|
          if message.workflow_state.in?(%w[pending failed unavailable])
            call(message, :expire, at:, superseded_by:)
          else
            message.with_lock { message.update!(superseded_by:) }
          end
        end
      end

      def initialize(message, event, at:, attributes:)
        @message = message
        @event = event.to_sym
        @at = at
        @attributes = attributes
      end

      def call
        message.with_lock do
          persist_legacy_projection!
          ensure_actionable!
          target_state = TRANSITIONS.fetch(event).fetch(message.action_state.to_sym) { raise_invalid_transition! }
          message.update!(transition_attributes(target_state))
        end

        message
      rescue KeyError
        raise InvalidTransition, "Unknown message transition: #{event}"
      end

      private

      def persist_legacy_projection!
        message.kind ||= message.backfill_kind
        message.action_state ||= message.workflow_state unless message.human_message?
        message.save! if message.changed?
      end

      def ensure_actionable!
        raise InvalidTransition, "Human messages do not have an action state" if message.human_message?
        raise InvalidTransition, "Message payload is unavailable" if !message.action_payload.valid? && event.in?(%i[acknowledge apply reject])
      end

      def raise_invalid_transition!
        raise InvalidTransition, "Cannot #{event} a message in #{message.action_state.inspect} state"
      end

      def transition_attributes(target_state)
        result = attributes.merge(action_state: target_state)
        result[:applied_at] = message.applied_at || at if target_state == :accepted
        result[:reverted_at] = message.reverted_at || at if target_state == :reverted
        result[:read_at] ||= at if event == :acknowledge && message.auto_applied? && message.read_at.blank?
        result
      end
    end
  end
end
