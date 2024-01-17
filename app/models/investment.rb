# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :bigint           not null
#  user_bank_account_id :bigint           not null
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Investment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include MoneyTransactable
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

  # Generates a description for the associated MoneyTransaction.
  #
  # This method generates a description for the MoneyTransaction based on the user's bank name and month_year.
  #
  # @return [String] The generated description.
  #
  def mt_description
    "Investment #{user_bank_account.bank.bank_name} #{month_year}"
  end

  # Generates a date for the associated MoneyTransaction.
  #
  # This method picks the end of given month for the MoneyTransaction.
  #
  # @return [Date]
  #
  def money_transaction_date
    end_of_month
  end

  # Generates a comment for the associated MoneyTransaction based on investment days.
  #
  # This method generates a comment listing the days of associated investments.
  #
  # @return [String] The generated comment.
  #
  def mt_comment
    "Days: [#{money_transaction.investments.order(:date).map(&:day).join(', ')}]"
  end

  # @private_instance_methods .................................................
end
