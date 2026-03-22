# frozen_string_literal: true

class Logic::ExchangeBackfillRunner
  VALID_INTENTS = %w[loan reimbursement].freeze

  attr_reader :users, :mapping, :dry_run

  def initialize(user_a:, user_b:, mapping:, dry_run: true)
    @users = [ user_a, user_b ]
    @mapping = mapping.stringify_keys
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      processed_cases: mapping.size,
      updated_messages_count: updates.size,
      skipped_cases_count: skipped.size,
      updates:,
      skipped:
    }
  end

  private

  def updates
    @updates ||= run_cases[:updates]
  end

  def skipped
    @skipped ||= run_cases[:skipped]
  end

  def run_cases # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    mapping.each_with_object({ updates: [], skipped: [] }) do |(source_id, intent), result| # rubocop:disable Metrics/BlockLength
      unless VALID_INTENTS.include?(intent)
        result[:skipped] << {
          source_transaction_id: source_id.to_i,
          reason: "unsupported_intent",
          intent:
        }
        next
      end

      source_transaction = root_transaction_for(source_id)

      if source_transaction.blank?
        result[:skipped] << {
          source_transaction_id: source_id.to_i,
          reason: "source_transaction_not_found"
        }
        next
      end

      counterpart_user = counterpart_user_for(source_transaction)

      if counterpart_user.blank?
        result[:skipped] << {
          source_transaction_id: source_transaction.id,
          reason: "counterpart_user_not_found"
        }
        next
      end

      receiver_reference = counterpart_user.cash_transactions.includes(
        :categories,
        :cash_installments,
        entity_transactions: %i[entity exchanges]
      ).find_by(reference_transactable: source_transaction)

      target_headers = build_target_headers(intent:, source_transaction:, counterpart_user:, receiver_reference:)

      if target_headers.blank?
        result[:skipped] << {
          source_transaction_id: source_transaction.id,
          reason: "target_headers_not_resolvable",
          intent:
        }
        next
      end

      messages = Message.where(reference_transactable: source_transaction).where.not(headers: [ nil, "" ])

      if messages.empty?
        result[:skipped] << {
          source_transaction_id: source_transaction.id,
          reason: "no_active_message_headers",
          intent:
        }
        next
      end

      messages.update_all(headers: JSON.generate(target_headers), updated_at: Time.current) unless dry_run

      result[:updates] << {
        source_transaction_id: source_transaction.id,
        intent:,
        message_ids: messages.pluck(:id),
        receiver_reference_transaction_id: receiver_reference&.id,
        target_headers:
      }
    end
  end

  def root_transaction_for(source_id)
    CashTransaction.includes(
      :categories,
      :cash_installments,
      entity_transactions: %i[entity exchanges]
    ).find_by(id: source_id, user: users, reference_transactable: nil)
  end

  def counterpart_user_for(transaction)
    transaction.entity_transactions.find do |entity_transaction|
      entity_transaction.exchanges_count.positive? &&
        users.include?(entity_transaction.entity.entity_user) &&
        entity_transaction.entity.entity_user != transaction.user
    end&.entity&.entity_user
  end

  def build_target_headers(intent:, source_transaction:, counterpart_user:, receiver_reference:)
    if receiver_reference.present?
      build_headers_from_receiver_reference(source_transaction:, receiver_reference:)
    elsif intent == "loan"
      exchanges = source_transaction.entity_transactions.find do |entity_transaction|
        entity_transaction.entity.entity_user == counterpart_user
      end&.exchanges

      source_transaction.send(:build_cash_transaction_headers, counterpart_user, exchanges)
    end
  end

  def build_headers_from_receiver_reference(source_transaction:, receiver_reference:) # rubocop:disable Metrics/AbcSize
    {
      id: source_transaction.id,
      type: source_transaction.class.name,
      description: receiver_reference.description,
      price: receiver_reference.price,
      date: serialized_datetime(receiver_reference.date),
      month: receiver_reference.month,
      year: receiver_reference.year,
      category_ids: receiver_reference.categories.first&.id,
      entity_ids: receiver_reference.entities.first&.id,
      cash_installments_attributes: receiver_reference.cash_installments.order(:number, :date).map do |installment|
        installment.slice(:number, :month, :year, :price).merge(date: serialized_datetime(installment.date))
      end,
      entity_transactions_attributes: receiver_reference.entity_transactions.order(:id).map do |entity_transaction|
        {
          is_payer: entity_transaction.is_payer,
          price: entity_transaction.price,
          price_to_be_returned: entity_transaction.price_to_be_returned,
          entity_id: entity_transaction.entity_id,
          exchanges_count: entity_transaction.exchanges_count,
          exchanges_attributes: entity_transaction.exchanges.order(:number, :date).map do |exchange|
            exchange.slice(:number, :month, :year, :price).merge(date: serialized_datetime(exchange.date))
          end
        }
      end
    }.compact
  end

  def serialized_datetime(value)
    value&.in_time_zone&.iso8601(3)
  end
end
