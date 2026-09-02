# frozen_string_literal: true

module Logic
  module Subscriptions
    class LifecycleTransition
      class InvalidTransition < StandardError
      end

      TRANSITIONS = {
        "pause" => { "active" => "paused" },
        "resume" => { "paused" => "active" },
        "finish" => { "active" => "finished", "paused" => "finished" },
        "reopen" => { "finished" => "active" }
      }.freeze

      attr_reader :subscription, :event

      def self.call(subscription:, event:)
        new(subscription:, event:).call
      end

      def initialize(subscription:, event:)
        @subscription = subscription
        @event = event.to_s
      end

      def call
        subscription.with_lock do
          target_status = TRANSITIONS.fetch(event).fetch(subscription.status) { raise_invalid_transition! }
          subscription.update!(status: target_status)
        end

        subscription
      rescue KeyError
        raise InvalidTransition, "Unknown Subscription lifecycle event: #{event.inspect}"
      end

      private

      def raise_invalid_transition!
        raise InvalidTransition, "Cannot #{event} a Subscription in #{subscription.status.inspect} state"
      end
    end
  end
end
