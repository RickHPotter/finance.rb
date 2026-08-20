# frozen_string_literal: true

module Logic
  module Messages
    ActionResult = Data.define(:status, :message_action, :error_code, :audit_operation) do
      def succeeded?
        status == :succeeded
      end

      def idempotent?
        status == :idempotent
      end

      def applied?
        succeeded? || idempotent?
      end
    end
  end
end
