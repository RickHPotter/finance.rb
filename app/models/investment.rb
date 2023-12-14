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
#  money_transaction_id :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Investment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include MoneyTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :category
  belongs_to :user_bank_account

  # @validations ..............................................................
  validates :price, :date, :user_id, :category_id, :user_bank_account_id, presence: true

  # @callbacks ................................................................
  # before_save :attach_money_transaction
  after_commit :update_money_transaction, on: %i[create update]
  after_commit :update_or_destroy_money_transaction, on: :destroy

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
