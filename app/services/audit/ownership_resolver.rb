# frozen_string_literal: true

class Audit::OwnershipResolver
  class UnsupportedRecordError < StandardError; end
  class UnresolvableOwnershipError < StandardError; end

  Ownership = Data.define(:owner_id, :context_id)

  DIRECT_CONTEXT_MODELS = %w[CashTransaction CardTransaction Budget Subscription Investment].freeze
  DIRECT_USER_MODELS = %w[UserCard UserBankAccount].freeze

  class << self
    def resolve!(record)
      ownership = resolve(record)
      raise UnresolvableOwnershipError, "owner could not be resolved for #{record.class.name}" if ownership.owner_id.blank?

      ownership
    end

    private

    def resolve(record)
      case record.class.name
      when *DIRECT_CONTEXT_MODELS then direct_context_ownership(record)
      when *DIRECT_USER_MODELS then Ownership.new(owner_id: record.user_id, context_id: nil)
      when "CashInstallment" then resolve_association(record, :cash_transaction)
      when "CardInstallment" then resolve_association(record, :card_transaction)
      when "CategoryTransaction", "EntityTransaction" then resolve_association(record, :transactable)
      when "Exchange" then resolve_association(record.entity_transaction, :transactable)
      when "Reference" then Ownership.new(owner_id: record.user_card&.user_id, context_id: record.context_id)
      when "PiggyBank" then resolve_piggy_bank(record)
      else raise UnsupportedRecordError, "no audit ownership resolver for #{record.class.name}"
      end
    end

    def direct_context_ownership(record)
      Ownership.new(owner_id: record.user_id, context_id: record.context_id)
    end

    def resolve_association(record, association)
      associated_record = record&.public_send(association)
      raise UnresolvableOwnershipError, "#{association} is unavailable for #{record&.class&.name}" if associated_record.blank?

      resolve(associated_record)
    end

    def resolve_piggy_bank(record)
      transaction = record.source_cash_transaction || record.return_cash_transaction
      raise UnresolvableOwnershipError, "PiggyBank has no source or return transaction" if transaction.blank?

      resolve(transaction)
    end
  end
end
