# frozen_string_literal: true

module Logic
  class SharedReturnStructureUpdateMessageService
    attr_reader :transaction

    def initialize(transaction:)
      @transaction = transaction
    end

    def call
      return false if counterpart_transaction.blank?
      return false if reference_transactable.blank?

      conversation = Conversation.find_or_create_assistant_between!(
        transaction.user,
        counterpart_transaction.user,
        scenario_key: transaction.context.scenario_key
      )
      headers = update_headers(counterpart_transaction.user).to_json

      return true if Message.exists?(conversation:, body: "notification:update", headers:, reference_transactable:)

      message = conversation.messages.create!(
        user: transaction.user,
        reference_transactable:,
        body: "notification:update",
        headers:
      )
      supersede_previous_messages(conversation, message)

      true
    end

    private

    def counterpart_transaction
      @counterpart_transaction ||= transaction.counterpart_shared_return_transaction
    end

    def reference_transactable
      @reference_transactable ||= counterpart_transaction if counterpart_transaction.is_a?(CashTransaction)
    end

    def update_headers(receiver)
      {
        version: "message_notification_v2",
        event: update_event(receiver),
        replay: update_replay
      }
    end

    def update_event(receiver)
      {
        action: "update",
        receiver_first_name: receiver.first_name,
        transaction_type: reference_transactable.class.name,
        details: update_event_details
      }
    end

    def update_replay
      {
        id: reference_transactable.id,
        type: reference_transactable.class.name,
        intent: transaction.try(:effective_friend_notification_intent),
        description: counterpart_transaction.description,
        price: total_price,
        date: first_desired_installment[:date]&.iso8601,
        month: first_desired_installment[:month],
        year: first_desired_installment[:year],
        category_ids: counterpart_transaction.categories.ids,
        entity_ids: counterpart_transaction.entities.ids,
        cash_installments_attributes: replay_cash_installments_attributes,
        entity_transactions_attributes: replay_entity_transactions_attributes
      }.compact_blank
    end

    def desired_installments
      @desired_installments ||= begin
        sign = counterpart_transaction.price.negative? ? -1 : 1

        transaction.cash_installments.order(:number, :date).map do |cash_installment|
          {
            number: cash_installment.number,
            date: cash_installment.date,
            month: cash_installment.month,
            year: cash_installment.year,
            price: cash_installment.price.abs * sign,
            paid: cash_installment.paid
          }
        end
      end
    end

    def update_event_details
      {
        transaction_label: reference_transactable.class.model_name.human,
        description: counterpart_transaction.description,
        date: first_desired_installment[:date]&.iso8601,
        reference_month_year: RefMonthYear.new(first_desired_installment[:month], first_desired_installment[:year]).numeric_month_year,
        price: total_price,
        installments_count: desired_installments.count,
        installments: event_installments
      }
    end

    def event_installments
      desired_installments.map do |installment|
        installment.slice(:number, :price).merge(date: installment[:date]&.iso8601)
      end
    end

    def replay_cash_installments_attributes
      desired_installments.map do |installment|
        installment.merge(date: installment[:date]&.iso8601)
      end
    end

    def replay_entity_transactions_attributes
      counterpart_transaction.entity_transactions.map do |entity_transaction|
        {
          id: entity_transaction.id,
          entity_id: entity_transaction.entity_id,
          is_payer: entity_transaction.is_payer,
          price: entity_transaction.price,
          price_to_be_returned: entity_transaction.price_to_be_returned,
          exchanges_count: entity_transaction.exchanges_count,
          exchanges_attributes: []
        }
      end
    end

    def total_price
      desired_installments.sum { |installment| installment[:price] }
    end

    def first_desired_installment
      desired_installments.first
    end

    def supersede_previous_messages(conversation, new_message)
      previous_messages = conversation.messages
                                      .merge(reference_scope_for(notification_reference_family))
                                      .where(superseded_by_id: nil)
                                      .where.not(id: new_message.id)

      previous_messages.update_all(superseded_by_id: new_message.id)
    end

    def notification_reference_family
      transaction.send(:notification_reference_family)
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
