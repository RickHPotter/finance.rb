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
        failure = check_preconditions
        return failure if failure

        original_operation = auto_apply_operation
        return Result.new(reverted?: false, failure_reason: "missing_audit") if original_operation.blank?

        ActiveRecord::Base.transaction do
          # Create a rollback operation linking to the original
          Audit::Operation.run(
            source: :rollback,
            actor: actor,
            parent_operation_id: message.audit_operation_id,
            rollback_of_operation_id: original_operation.id,
            join_existing: false
          ) do
            # The original auto_accept_actionable_message_service operation is where the cash transaction was created/updated.
            # We want to rollback the changes introduced in that operation.
            # Usually, PaperTrail allows reverting a version, but here we want to revert an entire operation.
            # The app likely has Audit::Rollback::Apply.

            result = Audit::Rollback::DirectApply.new(operation: original_operation, actor: actor).call

            raise ActiveRecord::Rollback unless result.status == "applied"

            message.update!(reverted_at: Time.current)
          end
        end

        if message.reverted?
          Result.new(reverted?: true)
        else
          Result.new(reverted?: false, failure_reason: "rollback_failed")
        end
      end

      private

      def check_preconditions
        return Result.new(reverted?: false, failure_reason: "unauthorized") if message.user_id == actor.id
        return Result.new(reverted?: false, failure_reason: "already_reverted") if message.reverted?
        return Result.new(reverted?: false, failure_reason: "not_auto_applied") unless message.auto_applied?

        nil
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
