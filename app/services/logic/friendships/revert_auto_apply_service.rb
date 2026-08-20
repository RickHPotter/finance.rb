# frozen_string_literal: true

module Logic
  module Friendships
    class RevertAutoApplyService
      Result = Struct.new(:reverted?, :failure_reason, keyword_init: true)

      attr_reader :message, :actor, :context

      def initialize(message:, actor:, context:)
        @message = message
        @actor = actor
        @context = context
      end

      def call
        conversation_policy.with_friendship_lock do
          message.with_lock do
            failure_reason = eligibility_failure_reason
            return denied_result(failure_reason) if failure_reason

            perform_rollback
          end
        end

        rollback_result
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :warning, context: { message_id: message.id, component: self.class.name })
        record_failure_action
        failed_result
      end

      def revertible?
        eligibility_failure_reason.nil?
      end

      private

      def perform_rollback
        ActiveRecord::Base.transaction do
          Audit::Operation.run(
            source: :rollback,
            actor: actor,
            parent_operation_id: message.audit_operation_id,
            rollback_of_operation_id: rollback_operation.id,
            join_existing: false
          ) do
            result = Audit::Rollback::DirectApply.new(operation: rollback_operation, actor: actor).call
            raise ActiveRecord::Rollback unless result.status == "applied"

            Logic::Messages::Transition.call(message, :revert)
            record_message_action(outcome: :succeeded, operation: result.operation)
          end
        end
      end

      def rollback_result
        return Result.new(reverted?: true) if message.reload.reverted?

        record_failure_action
        failed_result
      end

      def failed_result
        Result.new(reverted?: false, failure_reason: "rollback_failed")
      end

      def record_message_action(outcome:, operation: nil, error_code: nil, failure_reason: nil)
        friendship = message.conversation.friendship || message.user.friendship_with(actor)
        friend = message.conversation.friend_for(actor)
        return if friendship.blank? || friend.blank? || context.blank? || context.user_id != actor&.id

        MessageAction.create!(
          message:,
          conversation: message.conversation,
          friendship:,
          actor:,
          friend:,
          recipient_context: context,
          audit_operation: operation,
          scenario_key: message.conversation.scenario_key,
          action: :revert,
          initiator: :manual,
          outcome:,
          resulting_state: message.workflow_state,
          error_code:,
          metadata: { "failure_reason" => failure_reason }.compact
        )
      end

      def denied_result(failure_reason)
        outcome = failure_reason == "already_reverted" ? :idempotent : :denied
        record_message_action(outcome:, error_code: ledger_error_code(failure_reason), failure_reason:)
        Result.new(reverted?: false, failure_reason:)
      end

      def record_failure_action
        message.reload
        record_message_action(outcome: :failed, error_code: :persistence_failed, failure_reason: "rollback_failed")
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :warning, context: { message_id: message.id, component: self.class.name })
      end

      def ledger_error_code(failure_reason)
        {
          "unauthorized" => conversation_policy.failure_code || :wrong_recipient,
          "already_reverted" => :state_unavailable,
          "not_applied" => :state_unavailable,
          "superseded" => :superseded,
          "missing_audit" => :unavailable,
          "rollback_unavailable" => :unavailable
        }.fetch(failure_reason)
      end

      def eligibility_failure_reason
        if conversation_policy.failure_code.present? || actor.blank? || message.user_id == actor.id
          "unauthorized"
        elsif message.reverted?
          "already_reverted"
        elsif !message.applied?
          "not_applied"
        elsif message.superseded_by_id.present?
          "superseded"
        elsif rollback_operation.blank?
          "missing_audit"
        elsif rollback_preview.state != "previewable"
          "rollback_unavailable"
        end
      rescue StandardError
        "rollback_unavailable"
      end

      def rollback_preview
        Audit::Rollback::Preview.new(operation: rollback_operation, actor:)
      end

      def conversation_policy
        @conversation_policy ||= Logic::Conversations::Policy.new(conversation: message.conversation, actor:, context:)
      end

      def rollback_operation
        return @rollback_operation if defined?(@rollback_operation)

        @rollback_operation = message.auto_applied? ? auto_apply_operation : manual_apply_operation
      end

      def manual_apply_operation
        ledger_operation = message.message_actions.find_by(action: :apply, outcome: :succeeded)&.audit_operation
        return ledger_operation if ledger_operation.present?

        operation = message.audit_operation
        return if operation.blank?
        return unless operation.actor_id == actor.id && operation.context_id == context.id
        return if operation.audit_versions.none?

        operation
      end

      def auto_apply_operation
        return @auto_apply_operation if defined?(@auto_apply_operation)

        ledger_operation = message.message_actions.find_by(action: :apply, outcome: :succeeded)&.audit_operation
        return @auto_apply_operation = ledger_operation if ledger_operation.present?

        operation = message.audit_operation
        return @auto_apply_operation = nil if operation.blank?
        return @auto_apply_operation = operation if operation.source_actionable_message?

        candidates = AuditOperation.where(
          source: :actionable_message,
          result: :committed,
          parent_operation_id: operation.id,
          actor_id: actor.id
        )
        tagged_operation = candidates.where("metadata ->> 'actionable_message_id' = ?", message.id.to_s).first
        return @auto_apply_operation = tagged_operation if tagged_operation.present?

        legacy_candidates = candidates.limit(2).to_a
        @auto_apply_operation = legacy_candidates.one? ? legacy_candidates.first : nil
      end
    end
  end
end
