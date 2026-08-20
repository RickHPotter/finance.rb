# frozen_string_literal: true

module Logic
  module Messages
    class Apply < ActionBase
      RETRYABLE_STATES = %w[pending failed].freeze
      SUPPORTED_ACTIONS = %w[create update destroy].freeze

      attr_reader :target

      def initialize(message:, actor:, context:, initiator:, target: nil)
        super(message:, actor:, context:, initiator:)
        @target = target
      end

      def call(&)
        with_conversation_lock do
          message.with_lock do
            return idempotent_result(:apply) if message.applied? || successful_action(:apply)

            failure_code = eligibility_failure_code
            return deny!(failure_code) if failure_code

            perform_mutation!(&)
          end
        end
      rescue StandardError => e
        record_failure(e)
      end

      private

      def eligibility_failure_code
        identity_failure_code || state_failure_code || payload_failure_code || reference_failure_code || destroy_failure_code
      end

      def state_failure_code
        return :superseded if message.superseded_by_id.present?
        return if message.workflow_state.in?(RETRYABLE_STATES)

        :state_unavailable
      end

      def payload_failure_code
        return :invalid_payload unless message.action_payload.valid?
        return :unsupported_action unless message.action_payload.action.in?(SUPPORTED_ACTIONS)

        :unsupported_action if message.paid_state_sync_message?
      end

      def reference_failure_code
        return manual_reference_failure_code if initiator == :manual
        return if message.action_payload.action == "create"

        local_reference.present? ? nil : :local_reference_unavailable
      end

      def manual_reference_failure_code
        return :wrong_target if target&.user_id != actor.id || target&.context_id != context.id
        return if message.action_payload.action == "create"
        return if message.action_payload.action == "update" && target.persisted?
        return if message.action_payload.action == "update" && target.new_record? && local_reference.blank?
        return if local_reference == target

        :local_reference_changed
      end

      def destroy_failure_code
        return unless message.action_payload.action == "destroy"

        automatic_destroy_failure_code if initiator == :automatic
      end

      def automatic_destroy_failure_code
        transaction = local_reference
        return :unsafe_destroy unless transaction == message.reference_transactable
        return :unsafe_destroy unless safe_destroy_transaction_kind?(transaction)
        return :unsafe_destroy unless transaction.entities.that_are_users.where_entity_user(message.user).exists?

        :paid_history if transaction.paid_history?
      end

      def safe_destroy_transaction_kind?(transaction)
        linked_exchange =
          transaction.categories.exists?(category_name: "EXCHANGE") &&
          transaction.reference_transactable_type == "CashTransaction" &&
          transaction.reference_transactable_id.present?
        orphaned_borrow_return =
          transaction.categories.exists?(category_name: "BORROW RETURN") &&
          transaction.reference_transactable.blank?

        linked_exchange || orphaned_borrow_return
      end

      def local_reference
        @local_reference ||= message.local_reference_for(context:)
      end

      def perform_mutation!
        mutation_succeeded = yield
        return fail_validation! unless mutation_succeeded

        audit_operation = Audit::Operation.ensure_persisted!
        Transition.call(message, :apply, auto_applied: initiator == :automatic)
        event = record_action!(action: :apply, outcome: :succeeded, audit_operation:, metadata: action_metadata)
        result(:succeeded, message_action: event, audit_operation:)
      end

      def fail_validation!
        Transition.call(message, :fail) if message.workflow_state == "pending"
        event = record_action!(action: :apply, outcome: :failed, error_code: :validation_failed, metadata: action_metadata)
        result(:failed, message_action: event, error_code: :validation_failed)
      end

      def deny!(failure_code)
        if failure_code.in?(%i[friendship_unavailable invalid_payload local_reference_unavailable local_reference_changed superseded]) &&
           message.workflow_state.in?(RETRYABLE_STATES)
          Transition.call(message, :unavailable)
        end

        denied_result(:apply, failure_code, metadata: action_metadata)
      end

      def record_failure(error)
        Rails.error.report(error, handled: true, severity: :warning, context: { message_id: message.id, component: self.class.name })

        message.with_lock do
          Transition.call(message, :fail) if message.workflow_state == "pending"
          event = record_action!(action: :apply, outcome: :failed, error_code: :persistence_failed, metadata: action_metadata)
          result(:failed, message_action: event, error_code: :persistence_failed)
        end
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :warning, context: { message_id: message.id, component: self.class.name })
        result(:failed, error_code: :persistence_failed)
      end

      def action_metadata
        {
          "notification_action" => message.action_payload.action,
          "payload_digest" => Digest::SHA256.hexdigest(message.headers.to_s),
          "target_type" => target&.class&.name,
          "target_id" => target&.id
        }.compact
      end
    end
  end
end
