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
        failure_reason = eligibility_failure_reason
        return Result.new(reverted?: false, failure_reason:) if failure_reason

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
          end
        end

        if message.reverted?
          Result.new(reverted?: true)
        else
          Result.new(reverted?: false, failure_reason: "rollback_failed")
        end
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :warning, context: { message_id: message.id, component: self.class.name })
        Result.new(reverted?: false, failure_reason: "rollback_failed")
      end

      def revertible?
        eligibility_failure_reason.nil?
      end

      private

      def eligibility_failure_reason
        return @eligibility_failure_reason if defined?(@eligibility_failure_reason)

        @eligibility_failure_reason =
          if actor.blank? || message.user_id == actor.id
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
        @eligibility_failure_reason = "rollback_unavailable"
      end

      def rollback_preview
        @rollback_preview ||= Audit::Rollback::Preview.new(operation: rollback_operation, actor:)
      end

      def rollback_operation
        return @rollback_operation if defined?(@rollback_operation)

        @rollback_operation = message.auto_applied? ? auto_apply_operation : manual_apply_operation
      end

      def manual_apply_operation
        operation = message.audit_operation
        return if operation.blank?
        return unless operation.actor_id == actor.id && operation.context_id == context.id
        return if operation.audit_versions.none?

        operation
      end

      def auto_apply_operation
        return @auto_apply_operation if defined?(@auto_apply_operation)

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
