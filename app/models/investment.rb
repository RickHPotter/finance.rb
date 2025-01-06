# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  description          :string
#  price                :integer          not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :bigint           not null
#  user_bank_account_id :bigint           not null
#  cash_transaction_id  :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Investment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include CashTransactable
  include CategoryTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_bank_account

  # @validations ..............................................................
  validates :price, :date, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Generates an `description` for the associated `cash_transaction` based on the `user`'s `bank_name` and `month_year`.
  #
  # @return [String] The generated description.
  #
  def description
    "INVESTMENT #{user_bank_account.bank.bank_name} #{month_year}"
  end

  # Generates a `date` for the associated `cash_transaction`, picking the end of given `month` for the `cash_transaction`.
  #
  # @return [Date].
  #
  def cash_transaction_date
    end_of_month
  end

  # Generates a comment for the associated `cash_transaction` based on investment days.
  #
  # @return [String] The generated comment.
  #
  def comment
    "Days: [#{cash_transaction.investments.order(:date).map(&:day).join(', ')}]"
  end

  # Generates a `category_transactions` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions
    { category_id: user.built_in_category("INVESTMENT").id }
  end

  # Generates a `category_transactions_attributes` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions_attributes
    category_transactions.merge(id: nil)
  end

  # @private_instance_methods .................................................
end
