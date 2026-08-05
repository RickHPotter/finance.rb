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
          parent_operation_id: message.audit_operation_id,
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
        return false if message.transaction_destroy_notification_message?
        return false if message.paid_state_sync_message?

        payload = message.replay_payload || {}
        return false if contains_paid_installments?(payload)

        action = message.send(:notification_action)
        return false unless action.in?(%w[create update])

        if action == "update"
          reference = message.local_reference_for(context: friend_user.ensure_main_context!)
          return false if reference.blank?
        end

        true
      end

      def contains_paid_installments?(payload)
        installments = Array(payload["cash_installments_attributes"]) + Array(payload["card_installments_attributes"])
        return true if installments.any? { |inst| [ true, "true" ].include?(inst["paid"]) }

        Array(payload["entity_transactions_attributes"]).each do |et|
          exchanges = Array(et["exchanges_attributes"])
          return true if exchanges.any? { |ex| [ true, "true" ].include?(ex["paid"]) }
        end

        false
      end

      def apply! # rubocop:disable Metrics/AbcSize
        context = friend_user.ensure_main_context!
        action = message.send(:notification_action)
        attributes = build_attributes
        payload = message.replay_payload || {}
        category_id = Array(payload["category_ids"]).first

        ActiveRecord::Base.transaction do
          if action == "create"
            cash_transaction = context.cash_transactions.new(attributes.merge(user: friend_user, imported: false))
            cash_transaction.category_transactions.build(category_id: category_id) if category_id.present?
            cash_transaction.build_month_year if cash_transaction.user_bank_account_id
            raise ActiveRecord::Rollback unless cash_transaction.save
          elsif action == "update"
            cash_transaction = message.local_reference_for(context: context)

            if category_id.present?
              cash_transaction.category_transactions.each(&:mark_for_destruction)
              cash_transaction.category_transactions.build(category_id: category_id)
            end

            cash_transaction.assign_attributes(attributes.merge(imported: false))
            cash_transaction.build_month_year if cash_transaction.user_bank_account_id
            raise ActiveRecord::Rollback unless cash_transaction.save
          end

          message.update!(applied_at: Time.current)
        end
      end

      def build_attributes
        payload = message.replay_payload || {}

        {
          description: payload["description"],
          price: payload["price"],
          date: payload["date"],
          month: payload["month"],
          year: payload["year"],
          friend_notification_intent: payload["intent"],
          reference_transactable_type: payload["type"],
          reference_transactable_id: payload["id"],
          source_message_id: message.id,
          user_bank_account_id: friend_user.default_cash_transaction_user_bank_account,
          cash_installments_attributes: replay_cash_installments_attributes(payload),
          entity_transactions_attributes: replay_entity_transactions_attributes(payload)
        }.compact_blank.with_indifferent_access
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

      def replay_entity_transactions_attributes(payload) # rubocop:disable Metrics/AbcSize
        attributes = Array(payload["entity_transactions_attributes"]).map(&:with_indifferent_access)

        if message.send(:notification_action) == "update"
          cash_transaction = message.local_reference_for(context: friend_user.ensure_main_context!)
          if cash_transaction
            existing_by_entity = cash_transaction.entity_transactions.index_by(&:entity_id)
            attributes = attributes.map do |attrs|
              existing = existing_by_entity[attrs[:entity_id].to_i]
              next attrs unless existing

              if attrs[:exchanges_attributes].present?
                existing_ex_by_number = existing.exchanges.index_by(&:number)
                attrs[:exchanges_attributes] = attrs[:exchanges_attributes].map do |ex_attrs|
                  existing_ex = existing_ex_by_number[ex_attrs[:number].to_i]
                  ex_attrs.merge(id: existing_ex&.id).compact
                end
              end

              attrs.merge(id: existing.id).compact
            end
          end
        end

        attributes.presence
      end
    end
  end
end
