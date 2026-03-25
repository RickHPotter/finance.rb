# frozen_string_literal: true

module Logic
  class SharedPaidStateSyncService
    attr_reader :installment

    def initialize(installment:, force_notify: false)
      @installment = installment
      @force_notify = force_notify
    end

    def counterpart_installment
      @counterpart_installment ||= begin
        transaction = installment.cash_transaction
        counterpart_transaction = direct_counterpart_transaction(transaction) || mirrored_counterpart_transaction(transaction)
        counterpart_transaction&.cash_installments&.find_by(number: installment.number)
      end
    end

    def syncable?
      counterpart_installment.present?
    end

    def call
      return false unless syncable?

      counterpart_updated = false

      if counterpart_installment.paid != installment.paid
        counterpart_installment.skip_shared_paid_state_sync = true
        counterpart_installment.update!(paid: installment.paid)
        counterpart_updated = true
      end

      notify_counterpart_paid_state_change! if counterpart_updated || force_notify? || local_paid_state_changed?
      true
    end

    private

    attr_reader :force_notify

    def local_paid_state_changed?
      installment.saved_change_to_paid? || installment.previous_changes.key?("paid")
    end

    def force_notify?
      !!force_notify
    end

    def direct_counterpart_transaction(transaction)
      reference = transaction.reference_transactable
      return unless reference.is_a?(CashTransaction)
      return if reference.user_id == transaction.user_id

      reference
    end

    def mirrored_counterpart_transaction(transaction)
      counterpart_user = transaction.entities.that_are_users.first&.entity_user
      return if counterpart_user.blank?

      counterpart_context = if transaction.context.main? || transaction.context.scenario_key.blank?
                              counterpart_user.ensure_main_context!
                            else
                              counterpart_user.contexts.find_by(scenario_key: transaction.context.scenario_key)
                            end
      return if counterpart_context.blank?

      counterpart_context.cash_transactions.find_by(reference_transactable: transaction)
    end

    def notify_counterpart_paid_state_change!
      sender = installment.cash_transaction.user
      receiver = counterpart_installment.cash_transaction.user
      conversation = Conversation.find_or_create_assistant_between!(
        sender,
        receiver,
        scenario_key: installment.cash_transaction.context.scenario_key
      )
      headers = paid_state_headers(receiver).to_json

      return if Message.exists?(conversation:, body: "notification:paid_state", headers:)

      conversation.messages.create!(
        user: sender,
        reference_transactable: installment.cash_transaction,
        body: "notification:paid_state",
        headers:
      )
    end

    def paid_state_headers(receiver)
      {
        version: "message_paid_state_v1",
        event: {
          action: installment.paid? ? "paid" : "unpaid",
          receiver_first_name: receiver.first_name,
          transaction_type: "CashTransaction",
          details: {
            transaction_label: CashTransaction.model_name.human,
            description: installment.cash_transaction.description,
            installment_number: installment.number,
            installments_count: installment.cash_transaction.cash_installments_count,
            date: installment.date&.iso8601,
            paid: installment.paid
          }
        }
      }
    end
  end
end
