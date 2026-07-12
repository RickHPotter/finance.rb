# frozen_string_literal: true

module Logic
  class SharedReturnDestroyMessageService
    attr_reader :transaction, :counterpart_transaction

    def initialize(transaction:, counterpart_transaction:)
      @transaction = transaction
      @counterpart_transaction = counterpart_transaction
    end

    def call
      return false if counterpart_transaction.blank?

      conversation = Conversation.find_or_create_assistant_between!(
        transaction.user,
        counterpart_transaction.user,
        scenario_key: transaction.context.scenario_key
      )
      headers = destroy_headers(counterpart_transaction.user).to_json

      return true if Message.exists?(conversation:, body: "notification:destroy", headers:, reference_transactable: counterpart_transaction)

      message = conversation.messages.create!(
        user: transaction.user,
        reference_transactable: counterpart_transaction,
        body: "notification:destroy",
        headers:
      )
      supersede_previous_messages(conversation, message)

      true
    end

    private

    def destroy_headers(receiver)
      {
        version: "message_notification_v2",
        event: destroy_event(receiver),
        replay: nil
      }
    end

    def destroy_event(receiver)
      {
        action: "destroy",
        receiver_first_name: receiver.first_name,
        transaction_type: counterpart_transaction.class.name,
        details: destroy_event_details
      }
    end

    def destroy_event_details
      installments = counterpart_transaction.installments.order(:number, :date)

      {
        transaction_label: counterpart_transaction.class.model_name.human,
        description: counterpart_transaction.description,
        date: counterpart_transaction.date&.iso8601,
        reference_month_year: counterpart_transaction.respond_to?(:month_year) ? counterpart_transaction.month_year : nil,
        price: counterpart_transaction.price,
        installments_count: installments.size,
        installments: installments.map { |installment| installment.slice(:number, :price).merge(date: installment.date&.iso8601) }
      }
    end

    def supersede_previous_messages(conversation, new_message)
      previous_messages = conversation.messages
                                      .merge(reference_scope_for(notification_reference_family))
                                      .where(superseded_by_id: nil)
                                      .where.not(id: new_message.id)

      previous_messages.update_all(superseded_by_id: new_message.id)
    end

    def notification_reference_family
      [ *transaction.notification_message_reference_family, counterpart_transaction ].compact
    end

    def reference_scope_for(references)
      grouped_references = references.compact.uniq { |reference| [ reference.class.name, reference.id ] }.group_by(&:class)

      grouped_references.values.map do |group|
        Message.where(
          reference_transactable_type: group.first.class.name,
          reference_transactable_id: group.map(&:id)
        )
      end.reduce(Message.none, &:or)
    end
  end
end
