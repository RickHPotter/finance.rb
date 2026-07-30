# frozen_string_literal: true

class AllocationMutations::StructuralFamily
  CATEGORY_CODES = {
    "CARD PAYMENT" => :card_payment,
    "CARD ADVANCE" => :card_advance,
    "CARD INSTALLMENT" => :card_installment,
    "INVESTMENT" => :investment,
    "SUBSCRIPTION" => :subscription,
    "EXCHANGE" => :exchange,
    "EXCHANGE RETURN" => :exchange_return,
    "PIGGY BANK" => :piggy_bank,
    "PIGGY BANK RETURN" => :piggy_bank_return,
    "BORROW RETURN" => :borrow_return,
    "FAILED LEND/BORROW RETURN" => :failed_return
  }.freeze

  class << self
    def call(owner)
      adapter = AllocationMutations::OwnerAdapter.for(owner)
      codes = category_codes(adapter)

      append_transaction_codes(codes, owner, adapter) if owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction)
      codes.uniq.sort_by(&:to_s).freeze
    end

    private

    def category_codes(adapter)
      adapter.category_allocations.filter_map do |allocation|
        category = allocation.category
        CATEGORY_CODES[category&.category_name] if category&.built_in?
      end
    end

    def append_transaction_codes(codes, owner, adapter)
      codes << :subscription_owned if owner.subscription_id.present?
      codes << :generated_projection if owner.is_a?(CashTransaction) && owner.cash_transaction_type.present?
      codes << :payer_entity if adapter.entity_allocations.any?(&:is_payer?)
      codes << :exchange_bearing_entity if adapter.entity_allocations.any? { |allocation| allocation.exchanges_count.to_i.positive? }
      codes << :friend_identity if adapter.entity_allocations.any? { |allocation| allocation.entity&.entity_user_id.present? }
    end
  end
end
