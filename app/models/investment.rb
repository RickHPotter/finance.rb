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
  before_save :attach_money_transaction
  before_commit :update_money_transaction, unless: -> { destroyed? }
  before_commit :destroy_money_transaction, if: -> { destroyed? }

  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def attach_money_transaction
    self.money_transaction = MoneyTransaction.create_with(price:).find_or_create_by(
      mt_description:, date: end_of_month, month:, year:, user_id:, category_id:, user_bank_account_id:
    )
  end

  def perform_destroy_if_last
    money_transaction.destroy if money_transaction.investments.count.zero?
  end

  def update_money_transaction
    price = money_transaction.investments.sum(:price)
    mt_comment = investment_days_comment(money_transaction.investments)

    money_transaction.update(price:, mt_comment:)
  end

  def mt_description
    "Investment #{user_bank_account.bank.bank_name} #{month_year}"
  end

  def investment_days_comment(investments)
    "Days: [#{investments.pluck(:date).map(&:day).join(', ')}]"
  end
  # @private_instance_methods .................................................
end
