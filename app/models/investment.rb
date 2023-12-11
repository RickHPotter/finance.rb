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
  after_commit :update_money_transaction, on: %i[create update]
  after_commit :update_or_destroy_money_transaction, on: :destroy

  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Attachs a MoneyTransaction to the investment (by finding one or creating it).
  #
  # This method is a `before_save` callback that associates a MoneyTransaction with the investment.
  # It creates or finds a MoneyTransaction based on certain attributes and sets it to the `money_transaction`
  # attribute of the investment.
  #
  # @return [void]
  #
  # @see MoneyTransaction
  #
  def attach_money_transaction
    self.money_transaction = MoneyTransaction.create_with(price:).find_or_create_by(
      mt_description:, date: end_of_month, month:, year:, user_id:, category_id:, user_bank_account_id:
    )
  end

  # Updates the associated MoneyTransaction with investment details.
  #
  # This method is an `after_commit` callback triggered on `create` and `update` actions.
  # It updates the associated MoneyTransaction with the sum of investment prices and
  # a comment describing the days of associated investments.
  #
  # @return [void]
  #
  # @see MoneyTransaction
  #
  def update_money_transaction
    money_transaction.update(price: money_transaction.investments.sum(:price), mt_comment: investment_days_comment)
  end

  # Updates or destroys the associated MoneyTransaction based on investments count.
  #
  # This method is an `after_commit` callback triggered on `destroy` actions.
  # It checks the count of associated investments, and if zero, destroys the associated MoneyTransaction.
  # Otherwise, it updates the MoneyTransaction using {#update_money_transaction}.
  #
  # @return [void]
  #
  # @see update_money_transaction
  #
  def update_or_destroy_money_transaction
    if money_transaction.investments.count.zero?
      money_transaction.destroy
    else
      update_money_transaction
    end
  end

  # Generates a description for the associated MoneyTransaction.
  #
  # This method generates a description for the MoneyTransaction based on the user's bank name and month_year.
  #
  # @return [String] The generated description.
  #
  def mt_description
    "Investment #{user_bank_account.bank.bank_name} #{month_year}"
  end

  # Generates a comment for the associated MoneyTransaction based on investment days.
  #
  # This method generates a comment listing the days of associated investments.
  #
  # @return [String] The generated comment.
  #
  def investment_days_comment
    "Days: [#{money_transaction.investments.order(:date).map(&:day).join(', ')}]"
  end

  # @private_instance_methods .................................................
end
