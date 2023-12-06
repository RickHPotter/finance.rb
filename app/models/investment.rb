# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :integer          not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  money_transaction_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Investment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :category
  belongs_to :user_bank_account
  belongs_to :money_transaction, optional: true

  # @validations ..............................................................
  validates :price, :date, :user_id, :category_id, :user_bank_account_id, presence: true

  # @callbacks ................................................................
  before_save :increment_transaction
  after_destroy :decrement_transaction

  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def increment_transaction
    transaction = MoneyTransaction.first_or_create_by(
      mt_description:, date: end_of_month, month:, year:, user_id:, category_id:, user_bank_account_id:
    )

    transaction.investments << self
    update_transaction(transaction)
  end

  def decrement_transaction
    transaction = MoneyTransaction.find_by(mt_description:, month:, year:, user_id:, category_id:,
                                           user_bank_account_id:)

    transaction.investments.reject! { |i| i == self }
    if transaction.investments.empty?
      transaction.destroy
    else
      update_transaction(transaction)
    end
  end

  def update_transaction(transaction)
    price = transaction.investments.sum(:price)
    mt_comment = investment_days_comment(transaction.investments)
    transaction.update(price:, mt_comment:)
  end

  def mt_description
    "Investment #{user_bank_account.bank.bank_name} #{month_year}"
  end

  def investment_days_comment(investments)
    "Days: [#{investments.pluck(:date.day).join(', ')}]"
  end
  # @private_instance_methods .................................................
end
