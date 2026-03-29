# frozen_string_literal: true

class Logic::CardBoundExchangeIntegrityAudit
  attr_reader :ids, :year, :month

  def initialize(ids: nil, year: nil, month: nil)
    @ids = Array(ids).compact_blank.map(&:to_i)
    @year = year.presence&.to_i
    @month = month.presence&.to_i
  end

  def call
    {
      generated_at: Time.current.iso8601,
      families_count: candidates.size,
      candidates:
    }
  end

  private

  def candidates
    @candidates ||= orphan_families.filter_map do |family|
      issues = issues_for(family)
      next if issues.empty?

      serialize_family(family, issues)
    end
  end

  def orphan_families
    grouped_exchanges.values
  end

  def grouped_exchanges
    @grouped_exchanges ||= target_exchanges.group_by do |exchange|
      transactable = exchange.entity_transaction.transactable

      [
        transactable.user_id,
        transactable.context_id,
        transactable.user_card_id,
        exchange.send(:projection_description),
        exchange.year,
        exchange.month
      ]
    end
  end

  def target_exchanges
    @target_exchanges ||= begin
      scope = Exchange.includes(entity_transaction: :transactable)
                      .monetary
                      .card_bound
                      .where(cash_transaction_id: nil)
                      .order(:entity_transaction_id, :year, :month, :number, :date, :id)
      scope = scope.where(id: ids) if ids.present?
      scope = scope.where(year:) if year.present?
      scope = scope.where(month:) if month.present?

      scope.to_a
    end
  end

  def issues_for(family)
    issues = [ "missing_projection_cash_transaction" ]
    issues << "multiple_contexts_in_family" if family.map { |exchange| exchange.entity_transaction.transactable.context_id }.uniq.many?
    issues << "multiple_user_cards_in_family" if family.map { |exchange| exchange.entity_transaction.transactable.user_card_id }.uniq.many?
    issues << "existing_projection_cash_transaction_paid" if existing_projection_cash_transaction_for(family)&.paid_history?
    issues
  end

  def serialize_family(family, issues)
    first_exchange = family.first
    transactable = first_exchange.entity_transaction.transactable
    existing_projection = existing_projection_cash_transaction_for(family)

    {
      issues:,
      entity_transaction_ids: family.map(&:entity_transaction_id).uniq,
      user_id: transactable.user_id,
      context_id: transactable.context_id,
      user_card_id: transactable.user_card_id,
      year: first_exchange.year,
      month: first_exchange.month,
      exchanges_count: family.size,
      exchanges_sum_price: family.sum(&:price),
      expected_description: first_exchange.send(:projection_description),
      existing_projection_cash_transaction_id: existing_projection&.id,
      existing_projection_paid_history: existing_projection&.paid_history? || false,
      exchange_ids: family.map(&:id),
      exchanges: family.map do |exchange|
        {
          id: exchange.id,
          number: exchange.number,
          date: exchange.date&.to_date&.iso8601,
          month: exchange.month,
          year: exchange.year,
          price: exchange.price
        }
      end
    }
  end

  def existing_projection_cash_transaction_for(family)
    family.first.send(:existing_card_bound_projection_cash_transaction)
  end
end
