# frozen_string_literal: true

class Audit::Rollback::LockSet
  LOCKABLE_TYPES = %w[CashTransaction CardTransaction CashInstallment CardInstallment].freeze
  LOCK_ORDER = {
    "CashTransaction" => 0,
    "CardTransaction" => 1,
    "CashInstallment" => 2,
    "CardInstallment" => 3
  }.freeze

  attr_reader :preview

  def initialize(preview:)
    @preview = preview
  end

  def call
    lock_financial_records
    lock_routing_records
    lock_contexts
  end

  private

  def lock_financial_records
    financial_identities.each { |record_type, item_id| lock_record(record_type, item_id) }
  end

  def lock_record(record_type, item_id)
    if record_type.in?(%w[CashInstallment CardInstallment])
      record_type.constantize.unscoped.where(id: item_id, installment_type: record_type).lock.load
    else
      record_type.constantize.unscoped.where(id: item_id).lock.load
    end
  end

  def lock_routing_records
    impact = routing_impact
    UserBankAccount.where(id: impact.user_bank_account_ids).order(:id).lock.load
    UserCard.where(id: impact.user_card_ids).order(:id).lock.load
    Category.where(id: impact.cash_category_ids | impact.card_category_ids).order(:id).lock.load
    Entity.where(id: impact.cash_entity_ids | impact.card_entity_ids).order(:id).lock.load
  end

  def lock_contexts
    Context.where(id: preview.affected_context_ids).order(:id).lock.load
  end

  def financial_identities
    @financial_identities ||= begin
      identities = preview.rows.filter_map do |row|
        [ row.record_type, row.item_id ] if row.record_type.in?(LOCKABLE_TYPES)
      end
      preview.rows.each do |row|
        row.dependencies.each do |dependency|
          identities << [ dependency.record_type, dependency.item_id ] if dependency.record_type.in?(%w[CashTransaction CardTransaction])
        end
      end
      identities.uniq.sort_by { |record_type, item_id| [ LOCK_ORDER.fetch(record_type), item_id ] }
    end
  end

  def routing_impact
    @routing_impact ||= Audit::Rollback::Impact.new(preview:).tap do |impact|
      financial_identities.each do |record_type, item_id|
        next unless record_type.in?(%w[CashTransaction CardTransaction])

        impact.capture_transaction(record_type.constantize.unscoped.find_by(id: item_id))
      end
    end
  end
end
