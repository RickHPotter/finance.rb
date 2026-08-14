# frozen_string_literal: true

module Logic
  module Friendships
    class AutoAcceptActionableMessageService
      attr_reader :message

      def initialize(message)
        @message = message
      end

      def call
        return unless policy_allows?
        return unless safe?

        Audit::Operation.run(
          source: :actionable_message,
          actor: friend_user,
          context: friend_user.ensure_main_context!,
          parent_operation_id: message.audit_operation_id,
          metadata: { actionable_message_id: message.id },
          join_existing: false
        ) do
          apply!
        end
      end

      private

      def friend_user
        @friend_user ||= message.conversation.conversation_participants.where.not(user_id: message.user_id).first&.user
      end

      def policy_allows?
        return false unless friend_user

        # message.user is the *sender*; friend_user is the *recipient* whose
        # policy we are checking. friendship_with is symmetric — it returns the
        # same canonical Friendship record regardless of which user calls it —
        # so both directions resolve to the same row and the same policy value.
        friendship = message.user.friendship_with(friend_user)
        friendship&.auto_accept_actionable_messages == true
      end

      def safe?
        return false if message.applied_at.present? || message.reverted?
        return false if message.paid_state_sync_message?

        action = message.send(:notification_action)
        return safe_destroy? if action == "destroy"
        return false unless action.in?(%w[create update])

        if action == "update"
          reference = message.local_reference_for(context: friend_user.ensure_main_context!)
          return false if reference.blank?
        end

        true
      end

      def safe_destroy?
        cash_transaction = message.local_reference_for(context: friend_user.ensure_main_context!)

        cash_transaction.present? &&
          cash_transaction == message.reference_transactable &&
          cash_transaction.user_id == friend_user.id &&
          cash_transaction.context_id == friend_user.ensure_main_context!.id &&
          safe_destroy_transaction_kind?(cash_transaction) &&
          cash_transaction.entities.that_are_users.where_entity_user(message.user).exists? &&
          !cash_transaction.paid_history?
      end

      def safe_destroy_transaction_kind?(cash_transaction)
        linked_exchange =
          cash_transaction.categories.exists?(category_name: "EXCHANGE") &&
          cash_transaction.reference_transactable_type == "CashTransaction" &&
          cash_transaction.reference_transactable_id.present?
        orphaned_borrow_return =
          cash_transaction.categories.exists?(category_name: "BORROW RETURN") &&
          cash_transaction.reference_transactable.blank?

        linked_exchange || orphaned_borrow_return
      end

      def apply!
        context = friend_user.ensure_main_context!
        action = message.send(:notification_action)

        ActiveRecord::Base.transaction do
          apply_action!(action, context)
          auto_apply_operation = Audit::Operation.ensure_persisted!
          message.update!(applied_at: Time.current, auto_applied: true, audit_operation: auto_apply_operation)
        end

        # Best-effort broadcast outside the transaction — a render failure must
        # never roll back the already-committed cash transaction or applied_at stamp.
        message.reload
        Turbo::StreamsChannel.broadcast_replace_to(
          message.conversation,
          target: ActionView::RecordIdentifier.dom_id(message),
          html: ApplicationController.render(Views::Messages::Message.new(message: message), layout: false)
        )
      rescue StandardError => e
        Rails.logger.error("[AutoAcceptActionableMessageService] auto-apply failed: #{e.message}")
      end

      def apply_action!(action, context)
        case action
        when "destroy" then destroy_transaction!(context)
        when "create" then create_transaction!(context)
        when "update" then update_transaction!(context)
        end
      end

      def destroy_transaction!(context)
        cash_transaction = message.local_reference_for(context:)
        cash_transaction.source_message_id = message.id
        first_installment_date = cash_transaction.cash_installments.order(:date).pick(:date)
        Audit::BulkMutation.update_columns!(cash_transaction, date: first_installment_date) if first_installment_date.present?
        cash_transaction.destroy!
      end

      def create_transaction!(context)
        cash_transaction = context.cash_transactions.new(build_attributes.merge(user: friend_user, imported: false))
        cash_transaction.category_transactions.build(category_id:) if category_id.present?
        cash_transaction.build_month_year if cash_transaction.user_bank_account_id
        cash_transaction.save!
      end

      def update_transaction!(context)
        cash_transaction = message.local_reference_for(context:)

        if category_id.present? && cash_transaction.category_transactions.find_by(category_id:).blank?
          cash_transaction.category_transactions.each(&:mark_for_destruction)
          cash_transaction.category_transactions.build(category_id:)
        end

        cash_transaction.assign_attributes(build_attributes.merge(imported: false))
        cash_transaction.build_month_year if cash_transaction.user_bank_account_id
        cash_transaction.save!
      end

      def category_id
        @category_id ||= Array(message.replay_payload&.fetch("category_ids", nil)).first
      end

      def build_attributes
        payload = message.replay_payload || {}
        category_id = Array(payload["category_ids"]).first
        category_name = friend_user.categories.find_by(id: category_id)&.category_name
        is_exchange = category_name == "EXCHANGE"
        reference_attributes = replay_reference_attributes(payload, category_name:)

        attributes = {
          description: payload["description"],
          price: payload["price"],
          date: payload["date"],
          month: payload["month"],
          year: payload["year"],
          friend_notification_intent: (payload["intent"] if is_exchange),
          **reference_attributes,
          source_message_id: message.id,
          user_bank_account_id: friend_user.default_cash_transaction_user_bank_account,
          cash_installments_attributes: replay_cash_installments_attributes(payload),
          entity_transactions_attributes: replay_entity_transactions_attributes(payload)
        }.compact_blank.with_indifferent_access

        attributes[:friend_notification_intent] = is_exchange ? payload["intent"] : nil if category_id.present?
        attributes
      end

      def replay_reference_attributes(payload, category_name:)
        return {} if replay_payload_identifies_update_target?(payload)

        reference = replay_reference_transaction(payload, category_name:)

        {
          reference_transactable_type: reference&.class&.name || payload["type"],
          reference_transactable_id: reference&.id || payload["id"]
        }
      end

      def replay_payload_identifies_update_target?(payload)
        return false unless message.send(:notification_action) == "update"

        local_reference = message.local_reference_for(context: friend_user.ensure_main_context!)
        return false if local_reference.blank?

        payload["type"] == local_reference.class.name && payload["id"].to_s == local_reference.id.to_s
      end

      def replay_reference_transaction(payload, category_name:)
        requires_shared_return = category_name == "BORROW RETURN" || (category_name == "EXCHANGE" && payload["intent"] == "loan")
        return unless requires_shared_return

        reference_transaction = message.reference_transactable
        return unless reference_transaction.is_a?(CardTransaction) || reference_transaction.is_a?(CashTransaction)

        reference_transaction.entity_transactions
                             .includes(exchanges: :cash_transaction)
                             .flat_map(&:exchanges)
                             .select(&:monetary?)
                             .filter_map(&:cash_transaction)
                             .find(&:exchange_return?)
      end

      def replay_cash_installments_attributes(payload)
        attributes = Array(payload["cash_installments_attributes"]).map(&:with_indifferent_access)

        if message.send(:notification_action) == "update"
          cash_transaction = message.local_reference_for(context: friend_user.ensure_main_context!)
          if cash_transaction
            existing_by_number = cash_transaction.cash_installments.index_by(&:number)
            attributes = attributes.map do |attrs|
              existing = existing_by_number[attrs[:number].to_i]
              attrs.merge(id: existing&.id).compact
            end
          end
        end

        attributes
      end

      def replay_entity_transactions_attributes(payload)
        attributes = Array(payload["entity_transactions_attributes"]).map do |entity_attributes|
          entity_attributes = entity_attributes.with_indifferent_access
          exchanges_attributes = Array(entity_attributes[:exchanges_attributes]).map do |exchange_attributes|
            exchange_attributes.with_indifferent_access.except(:paid)
          end

          entity_attributes.merge(exchanges_attributes:)
        end

        if message.send(:notification_action) == "update"
          cash_transaction = message.local_reference_for(context: friend_user.ensure_main_context!)
          if cash_transaction
            existing_by_entity = cash_transaction.entity_transactions.index_by(&:entity_id)
            attributes = attributes.map do |attrs|
              existing = existing_by_entity[attrs[:entity_id].to_i]
              next attrs unless existing

              attrs = synchronize_replayed_exchanges(attrs, existing) if attrs.key?(:exchanges_attributes)

              attrs.merge(id: existing.id).compact
            end
          end
        end

        attributes.presence
      end

      def synchronize_replayed_exchanges(attributes, entity_transaction)
        existing_by_number = entity_transaction.exchanges.index_by(&:number)
        replayed = Array(attributes[:exchanges_attributes]).map do |exchange_attributes|
          existing = existing_by_number[exchange_attributes[:number].to_i]
          exchange_attributes.merge(id: existing&.id).compact
        end
        replayed_numbers = replayed.pluck(:number).map(&:to_i)
        removed = entity_transaction.exchanges.reject { |exchange| replayed_numbers.include?(exchange.number) }.map do |exchange|
          { id: exchange.id, _destroy: true }
        end

        attributes.merge(exchanges_attributes: replayed + removed)
      end
    end
  end
end
