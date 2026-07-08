# frozen_string_literal: true

module Logic
  class SharedPaidStateSyncService # rubocop:disable Metrics/ClassLength
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
      return create_counterpart_structure_update_message if counterpart_structure_update_required?

      counterpart_updated = false

      counterpart_attributes = counterpart_installment_attributes
      recalculation_start = counterpart_recalculation_start(counterpart_attributes)

      CashInstallment.transaction do
        if counterpart_sync_required?(counterpart_attributes)
          counterpart_installment.skip_shared_paid_state_sync = true
          counterpart_installment.update!(counterpart_attributes)
          sync_counterpart_transaction_state!
          recalculate_counterpart_balances!(recalculation_start)
          counterpart_updated = true
        end

        notify_counterpart_paid_state_change! if counterpart_updated || force_notify? || local_paid_state_changed?
      end

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
      chain_counterpart = transaction.counterpart_shared_return_transaction if transaction.respond_to?(:counterpart_shared_return_transaction)
      return chain_counterpart if chain_counterpart.present? && chain_counterpart.user_id != transaction.user_id

      reference = transaction.reference_transactable
      return unless reference.is_a?(CashTransaction)
      return if reference.user_id == transaction.user_id
      return unless reference.exchange_return? || reference.borrow_return?

      reference
    end

    def mirrored_counterpart_transaction(transaction)
      return transaction.counterpart_shared_return_transaction if transaction.respond_to?(:counterpart_shared_return_transaction)

      counterpart_user =
        if transaction.respond_to?(:counterpart_shared_return_user)
          transaction.counterpart_shared_return_user
        else
          transaction.entities.that_are_users.first&.entity_user
        end
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
      return create_counterpart_structure_update_message if open_actionable_update_exists?

      sender = installment.cash_transaction.user
      receiver = counterpart_installment.cash_transaction.user
      conversation = Conversation.find_or_create_assistant_between!(
        sender,
        receiver,
        scenario_key: installment.cash_transaction.context.scenario_key
      )
      headers = paid_state_headers(receiver).to_json

      return if Message.exists?(conversation:, body: "notification:paid_state", headers:, reference_transactable: installment.cash_transaction)

      conversation.messages.create!(
        user: sender,
        reference_transactable: installment.cash_transaction,
        body: "notification:paid_state",
        headers:
      )
    end

    def create_counterpart_structure_update_message # rubocop:disable Naming/PredicateMethod
      sender = installment.cash_transaction.user
      receiver = counterpart_installment.cash_transaction.user
      reference_transactable = structure_update_reference_transactable
      conversation = Conversation.find_or_create_assistant_between!(
        sender,
        receiver,
        scenario_key: installment.cash_transaction.context.scenario_key
      )
      headers = counterpart_update_headers(receiver, reference_transactable).to_json

      return true if Message.exists?(conversation:, body: "notification:update", headers:, reference_transactable:)

      message = conversation.messages.create!(
        user: sender,
        reference_transactable:,
        body: "notification:update",
        headers:
      )
      supersede_previous_messages(conversation, message)

      true
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

    def counterpart_update_headers(receiver, reference_transactable)
      update_context = counterpart_update_context(reference_transactable)

      {
        version: "message_notification_v2",
        event: counterpart_update_event(receiver, update_context),
        replay: counterpart_update_replay(update_context)
      }
    end

    def counterpart_update_context(reference_transactable)
      desired_installments = desired_counterpart_installments
      counterpart_transaction = counterpart_installment.cash_transaction
      replay_transaction = counterpart_replay_transaction(reference_transactable, counterpart_transaction)
      entity_source_transaction = counterpart_replay_entity_source_transaction(reference_transactable, replay_transaction)

      {
        desired_installments:,
        counterpart_transaction:,
        replay_transaction:,
        entity_source_transaction:,
        replay_cash_installments: replay_cash_installments(reference_transactable, replay_transaction, desired_installments),
        total_price: desired_installments.sum { |installment_attributes| installment_attributes[:price] },
        first_installment: desired_installments.first,
        reference_transactable:
      }
    end

    def counterpart_update_event(receiver, update_context)
      {
        action: "update",
        receiver_first_name: receiver.first_name,
        transaction_type: update_context[:reference_transactable].class.name,
        details: {
          transaction_label: update_context[:reference_transactable].class.model_name.human,
          description: update_context[:counterpart_transaction].description,
          date: update_context[:first_installment][:date]&.iso8601,
          reference_month_year: RefMonthYear.new(update_context[:first_installment][:month], update_context[:first_installment][:year]).numeric_month_year,
          price: update_context[:total_price],
          installments_count: update_context[:desired_installments].count,
          installments: update_context[:desired_installments].map do |installment_attributes|
            installment_attributes.slice(:number, :price).merge(date: installment_attributes[:date]&.iso8601)
          end
        }
      }
    end

    def counterpart_update_replay(update_context)
      replay_transaction = update_context[:replay_transaction]

      {
        id: update_context[:reference_transactable].id,
        type: update_context[:reference_transactable].class.name,
        intent: installment.cash_transaction.try(:effective_friend_notification_intent),
        description: replay_transaction.description,
        price: replay_transaction.price,
        date: replay_transaction.date&.iso8601,
        month: replay_transaction.month,
        year: replay_transaction.year,
        category_ids: replay_transaction.categories.ids,
        entity_ids: replay_transaction.entities.ids,
        cash_installments_attributes: update_context[:replay_cash_installments]&.map do |installment_attributes|
          installment_attributes.merge(date: installment_attributes[:date]&.iso8601)
        end,
        entity_transactions_attributes: counterpart_entity_transactions_attributes(
          replay_transaction,
          source_transaction: update_context[:entity_source_transaction]
        )
      }.compact_blank
    end

    def structure_update_reference_transactable
      transaction = installment.cash_transaction

      transaction.exchanges.includes(entity_transaction: :transactable).first&.entity_transaction&.transactable ||
        transaction.reference_transactable ||
        transaction
    end

    def counterpart_entity_transactions_attributes(counterpart_transaction, source_transaction: counterpart_transaction)
      target_entity_transactions = counterpart_transaction.entity_transactions.to_a
      source_sign_multiplier = replay_sign_multiplier(counterpart_transaction, source_transaction)

      source_transaction.entity_transactions.each_with_index.map do |entity_transaction, index|
        serialize_counterpart_entity_transaction(
          entity_transaction,
          target_entity_transactions:,
          index:,
          source_sign_multiplier:
        )
      end
    end

    def counterpart_replay_transaction(reference_transactable, counterpart_transaction)
      local_projection = counterpart_transaction.reference_transactable

      return counterpart_transaction unless reference_transactable.is_a?(CashTransaction)
      return counterpart_transaction unless local_projection.is_a?(CashTransaction)
      return counterpart_transaction unless local_projection.user_id == counterpart_transaction.user_id
      return counterpart_transaction if local_projection == counterpart_transaction
      return counterpart_transaction if local_projection == reference_transactable

      local_projection
    end

    def counterpart_replay_entity_source_transaction(reference_transactable, replay_transaction)
      return reference_transactable if cash_root_exchange_projection?(reference_transactable, replay_transaction)

      replay_transaction
    end

    def replay_cash_installments(reference_transactable, replay_transaction, desired_installments)
      return if cash_root_exchange_projection?(reference_transactable, replay_transaction)

      desired_installments if replay_transaction == counterpart_installment.cash_transaction
    end

    def cash_root_exchange_projection?(reference_transactable, replay_transaction)
      installment.cash_transaction.try(:effective_friend_notification_intent) == "loan" &&
        reference_transactable.is_a?(CashTransaction) &&
        replay_transaction.is_a?(CashTransaction) &&
        replay_transaction.user_id == counterpart_installment.cash_transaction.user_id &&
        reference_transactable.user_id != replay_transaction.user_id &&
        replay_transaction.categories.exists?(category_name: "EXCHANGE")
    end

    def replay_sign_multiplier(counterpart_transaction, source_transaction)
      return 1 if counterpart_transaction == source_transaction

      counterpart_transaction.price.to_i.positive? == source_transaction.price.to_i.positive? ? 1 : -1
    end

    def counterpart_entity_transaction_target(target_entity_transactions, source_entity_transaction, index)
      target_entity_transactions.find { |entity_transaction| entity_transaction.is_payer == source_entity_transaction.is_payer } ||
        target_entity_transactions[index]
    end

    def serialize_counterpart_entity_transaction(source_entity_transaction, target_entity_transactions:, index:, source_sign_multiplier:)
      target_entity_transaction = counterpart_entity_transaction_target(target_entity_transactions, source_entity_transaction, index)

      {
        id: target_entity_transaction&.id || source_entity_transaction.id,
        entity_id: target_entity_transaction&.entity_id || source_entity_transaction.entity_id,
        is_payer: target_entity_transaction&.is_payer.nil? ? source_entity_transaction.is_payer : target_entity_transaction.is_payer,
        price: source_entity_transaction.price * source_sign_multiplier,
        price_to_be_returned: source_entity_transaction.price_to_be_returned * source_sign_multiplier,
        loan_return_percentage: source_entity_transaction.loan_return_percentage,
        exchanges_count: source_entity_transaction.exchanges_count,
        exchanges_attributes: serialize_counterpart_exchanges(target_entity_transaction, source_entity_transaction, source_sign_multiplier)
      }
    end

    def serialize_counterpart_exchanges(target_entity_transaction, source_entity_transaction, source_sign_multiplier)
      target_exchanges_by_number = target_entity_transaction&.exchanges&.index_by(&:number) || {}

      source_entity_transaction.exchanges.order(:number, :date).map do |exchange|
        {
          id: target_exchanges_by_number[exchange.number]&.id,
          number: exchange.number,
          date: exchange.date&.iso8601,
          month: exchange.month,
          year: exchange.year,
          price: exchange.price * source_sign_multiplier,
          paid: exchange.mirrored_paid?
        }.compact
      end
    end

    def counterpart_installment_attributes
      {
        paid: installment.paid,
        date: installment.date,
        month: installment.month,
        year: installment.year
      }
    end

    def counterpart_sync_required?(attributes)
      attributes.any? do |key, value|
        counterpart_installment.public_send(key) != value
      end
    end

    def counterpart_recalculation_start(attributes)
      original_date = counterpart_installment.date
      incoming_date = attributes[:date]
      earliest_date = [ original_date, incoming_date ].compact.min

      {
        year: earliest_date&.year || attributes[:year] || counterpart_installment.year,
        month: earliest_date&.month || attributes[:month] || counterpart_installment.month
      }
    end

    def sync_counterpart_transaction_state!
      transaction = counterpart_installment.cash_transaction

      transaction.update_columns(paid: transaction.cash_installments.where(paid: false).none?)
      return unless transaction.exchange_return?

      counterpart_installment.send(:sync_mirrored_exchange_settlement!)
      transaction.sync_exchange_entity_transaction_statuses!
    end

    def recalculate_counterpart_balances!(recalculation_start)
      transaction = counterpart_installment.cash_transaction

      Logic::RecalculateBalancesService.new(
        user: transaction.user,
        context: transaction.context,
        year: recalculation_start[:year],
        month: recalculation_start[:month]
      ).call
    end

    def counterpart_structure_update_required?
      installment.cash_transaction.cash_installments_count != counterpart_installment.cash_transaction.cash_installments_count
    end

    def desired_counterpart_installments
      sign = counterpart_installment.cash_transaction.price.negative? ? -1 : 1

      structure_source_transaction.cash_installments.order(:number, :date).map do |cash_installment|
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

    def structure_source_transaction
      transaction = installment.cash_transaction
      return transaction unless transaction.respond_to?(:counterpart_shared_return_transaction)

      counterpart_transaction = transaction.counterpart_shared_return_transaction
      return transaction if counterpart_transaction.blank?

      sender_shared_return_candidate = [ transaction, counterpart_transaction ].find do |candidate|
        candidate.respond_to?(:exchange_return?) && candidate.exchange_return?
      end

      sender_shared_return_candidate || transaction
    end

    def open_actionable_update_exists?
      sender = installment.cash_transaction.user
      receiver = counterpart_installment.cash_transaction.user
      conversation = Conversation.find_or_create_assistant_between!(
        sender,
        receiver,
        scenario_key: installment.cash_transaction.context.scenario_key
      )
      reference_family = installment.cash_transaction.notification_message_reference_family

      conversation.messages
                  .merge(reference_scope_for(reference_family))
                  .where(body: "notification:update", superseded_by_id: nil, applied_at: nil)
                  .exists?
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

    def supersede_previous_messages(conversation, new_message)
      reference_family = installment.cash_transaction.notification_message_reference_family
      previous_messages = conversation.messages
                                      .merge(reference_scope_for(reference_family))
                                      .where(superseded_by_id: nil)
                                      .where.not(id: new_message.id)

      previous_messages.update_all(superseded_by_id: new_message.id)
    end
  end
end
