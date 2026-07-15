# frozen_string_literal: true

# Category-family rules shared by transaction models.
module PiggyBankCategorizable
  extend ActiveSupport::Concern

  EXCHANGE_CATEGORY_NAMES = [ "EXCHANGE", "EXCHANGE RETURN" ].freeze
  PIGGY_BANK_CATEGORY_NAMES = [ "PIGGY BANK", "PIGGY BANK RETURN" ].freeze

  included do
    validate :validate_piggy_bank_category_contract
  end

  def active_category_names
    active_category_transactions.filter_map do |category_transaction|
      category_transaction.category&.category_name || category_name_for(category_transaction.category_id)
    end.uniq
  end

  def piggy_bank_source?
    active_category_names.include?("PIGGY BANK")
  end

  def piggy_bank_return?
    active_category_names.include?("PIGGY BANK RETURN") || (respond_to?(:cash_transaction_type) && cash_transaction_type == "PiggyBank")
  end

  private

  def validate_piggy_bank_category_contract
    names = active_category_names
    errors.add(:base, :mixed_exchange_and_piggy_bank_categories) if names.intersect?(EXCHANGE_CATEGORY_NAMES) && names.intersect?(PIGGY_BANK_CATEGORY_NAMES)
    errors.add(:base, :mixed_piggy_bank_categories) if names.intersect?(PIGGY_BANK_CATEGORY_NAMES) && (names & PIGGY_BANK_CATEGORY_NAMES).many?
    errors.add(:base, :mixed_exchange_categories) if (names & EXCHANGE_CATEGORY_NAMES).many?

    validate_model_piggy_bank_categories(names)
  end

  def validate_model_piggy_bank_categories(names)
    if is_a?(CardTransaction) && names.intersect?(PIGGY_BANK_CATEGORY_NAMES)
      errors.add(:base, :piggy_bank_cash_only)
    elsif is_a?(CashTransaction) && names.include?("PIGGY BANK RETURN") && !piggy_bank_projection_write?
      errors.add(:base, :piggy_bank_return_system_managed)
    end
  end

  def active_category_transactions
    category_transactions.reject(&:marked_for_destruction?)
  end

  def category_name_for(category_id)
    return if category_id.blank? || user.blank?

    user.categories.find_by(id: category_id)&.category_name
  end

  def piggy_bank_projection_write?
    respond_to?(:piggy_bank_projection_write) && ActiveModel::Type::Boolean.new.cast(piggy_bank_projection_write)
  end
end
