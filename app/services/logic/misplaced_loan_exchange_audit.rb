# frozen_string_literal: true

module Logic
  class MisplacedLoanExchangeAudit
    attr_reader :connected_user_id, :current_user

    def initialize(current_user:, connected_user_id: nil)
      @current_user = current_user
      @connected_user_id = connected_user_id.presence&.to_i
    end

    def call
      rows = source_rows.filter_map do |source_id, rows|
        source = source_transactions[source_id]
        next if source.blank?

        build_row(source, rows)
      end

      rows.sort_by { |row| [ row[:latest_message_at] || Time.zone.at(0), row[:source_id] ] }.reverse
    end

    def convert!(source_id:)
      row = call.find { |candidate| candidate[:source_id] == source_id.to_i }
      raise ActiveRecord::RecordNotFound if row.blank?

      source = source_transactions.fetch(row[:source_id])
      message_ids = row[:message_ids]

      CashTransaction.transaction do
        source.update!(friend_notification_intent: "reimbursement")
        rewrite_message_intents!(message_ids)
      end

      {
        source_id: source.id,
        updated_message_count: message_ids.size
      }
    end

    def convert_exchange_audit_issue!(source_id:)
      source_id = source_id.to_i
      source = CashTransaction.find_by(id: source_id)
      return unavailable_conversion_result(source_id:, reason: "not_found") if source.blank?
      return unavailable_conversion_result(source_id:, reason: "owner_only") if source.user_id != current_user.id
      return unavailable_conversion_result(source_id:, reason: "issue_not_found") unless exchange_loan_source?(source)

      message_ids = source.active_notification_messages.pluck(:id)

      CashTransaction.transaction do
        source.update!(friend_notification_intent: "reimbursement")
        rewrite_message_intents!(message_ids)
      end

      {
        status: "converted",
        source_id: source.id,
        updated_message_count: message_ids.size
      }
    end

    private

    def exchange_loan_source?(source)
      source.exchange_category? && source.effective_friend_notification_intent == "loan"
    end

    def unavailable_conversion_result(source_id:, reason:)
      {
        status: "unavailable",
        source_id:,
        reason:,
        updated_message_count: 0
      }
    end

    def source_rows
      @source_rows ||= exchange_rows
                       .select { |row| current_user_source_loan_row?(row) }
                       .group_by { |row| row.dig(:source, :id) }
    end

    def current_user_source_loan_row?(row)
      row[:intent] == "loan" &&
        row.dig(:source, :type) == "CashTransaction" &&
        row.dig(:source, :user_id).to_i == current_user.id
    end

    def exchange_rows
      scope = Logic::ExchangeTrioAudit.new(current_user:, connected_user_id:).call
      Logic::ExchangeAuditSelectionProjector.new(rows: scope).call
    end

    def source_transactions
      @source_transactions ||= CashTransaction
                               .includes(:cash_installments, :categories, entity_transactions: :entity)
                               .where(user_id: current_user.id, id: source_rows.keys)
                               .index_by(&:id)
    end

    def build_row(source, rows)
      transaction_total = source.price.to_i.abs
      entity_return_total = source.entity_transactions.sum { |entity_transaction| entity_transaction.price_to_be_returned.to_i.abs }
      return if transaction_total == entity_return_total

      latest_message = latest_message_for(rows)
      {
        source_id: source.id,
        description: source.description,
        date: source.date,
        month_year: source.month_year,
        transaction_total:,
        entity_return_total:,
        delta: transaction_total - entity_return_total,
        entity_rows: entity_rows_for(source),
        latest_message: serialize_message(latest_message),
        latest_message_replay_intent: latest_message&.replay_payload.to_h["intent"],
        latest_message_at: latest_message&.created_at,
        message_ids: rows.filter_map { |row| row.dig(:message, :id) }.uniq,
        impacted_rows_count: rows.size,
        projected_intent: "reimbursement",
        projected_chain_kind: "shared_return_chain",
        projected_end_kind: "shared_return"
      }
    end

    def entity_rows_for(source)
      source.entity_transactions.map do |entity_transaction|
        {
          id: entity_transaction.id,
          entity_name: entity_transaction.entity&.entity_name,
          price: entity_transaction.price,
          price_to_be_returned: entity_transaction.price_to_be_returned
        }
      end
    end

    def latest_message_for(rows)
      message_ids = rows.filter_map { |row| row.dig(:message, :id) }
      Message.where(id: message_ids).order(created_at: :desc, id: :desc).first
    end

    def serialize_message(message)
      return if message.blank?

      {
        id: message.id,
        conversation_id: message.conversation_id,
        body: message.preview_body,
        created_at: message.created_at
      }
    end

    def rewrite_message_intents!(message_ids)
      Message.where(id: message_ids).find_each do |message|
        headers = parsed_headers_for(message)
        next if headers.blank?

        headers["intent"] = "reimbursement" if headers.key?("intent")
        headers["replay"]["intent"] = "reimbursement" if headers["replay"].is_a?(Hash)
        message.update!(headers: headers.to_json)
      end
    end

    def parsed_headers_for(message)
      JSON.parse(message.headers.to_s)
    rescue JSON::ParserError
      nil
    end
  end
end
