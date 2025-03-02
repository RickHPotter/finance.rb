# frozen_string_literal: true

module Logic
  class CashTransactions
    def self.create_from(attributes = {})
      user_bank_account = attributes[:user_bank_account]
      entity = attributes[:entity]
      category = attributes[:category]

      if user_bank_account.nil?
        user = entity&.user || category&.user
        user_bank_account = user.user_bank_accounts.first
      end

      cash_transaction = user_bank_account.cash_transactions.new
      cash_transaction.build_month_year
      cash_transaction.entity_transactions.new(entity:) if entity
      cash_transaction.category_transactions.new(category:) if category
      cash_transaction
    end

    def self.find_by_ref_month_year(user, params)
      month_year = params.delete(:month_year)
      month = month_year[4..]
      year = month_year[0..3]

      raw_conditions = build_conditions_from_params(params)

      [
        Logic::CashInstallments.find_by_ref_month_year(user, month, year, raw_conditions),
        Logic::Budgets.find_by_ref_month_year(user, month, year, raw_conditions)
      ]
    end

    def self.build_conditions_from_params(params)
      params.delete(:controller)
      params.delete(:action)

      return {} if params.blank?

      {
        price: build_price_range_conditions(params),
        installments_price: build_cash_transaction_price_range_conditions(params),
        cash_installments_count: build_installments_count_range_conditions(params),
        search_term: params.delete(:search_term),
        associations: build_conditions_for_associations(params)
      }.compact_blank
    end

    def self.build_price_range_conditions(params)
      from_price = params.delete(:from_price).to_i
      to_price = params.delete(:to_price).to_i
      return nil if from_price.zero? && to_price.zero?

      from_price ||= 0
      to_price   ||= from_price if from_price
      from_price, to_price = to_price, from_price if from_price > to_price

      (from_price..to_price)
    end

    def self.build_cash_transaction_price_range_conditions(params)
      from_ct_price = params.delete(:from_ct_price).to_i
      to_ct_price = params.delete(:to_ct_price).to_i
      return nil if from_ct_price.zero? && to_ct_price.zero?

      from_ct_price ||= 0
      to_ct_price   ||= from_ct_price if from_ct_price
      from_ct_price, to_ct_price = to_ct_price, from_ct_price if from_ct_price > to_ct_price

      (from_ct_price..to_ct_price)
    end

    def self.build_installments_count_range_conditions(params)
      from_installments_count = params.delete(:from_installments_count).to_i
      to_installments_count = params.delete(:to_installments_count).to_i
      return nil if from_installments_count.zero? && to_installments_count.zero?

      from_installments_count ||= 1
      to_installments_count   ||= from_installments_count
      from_installments_count, to_installments_count = to_installments_count, from_installments_count if from_installments_count > to_installments_count

      (from_installments_count..to_installments_count)
    end

    def self.build_conditions_for_associations(params)
      category_id = (params.delete(:category_id) || params.delete(:category_ids) || {}).compact_blank
      entity_id = (params.delete(:entity_id) || params.delete(:entity_ids) || {}).compact_blank

      {
        categories: { id: category_id }.compact_blank,
        entities: { id: entity_id }.compact_blank
      }.compact_blank
    end
  end
end
