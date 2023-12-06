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
#  transaction_id       :integer          not null
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

  # @validations ..............................................................
  validates :price, :date, :user_id, :category_id, :user_bank_account_id, presence: true

  # @callbacks ................................................................
  after_save :calculate_transaction_by_ref_month_year

  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def calculate_transaction_by_ref_month_year
    transaction = Transaction.first_or_create(
      t_description:, date: end_of_month, month:, year:,
      user_id:, category_id:, user_bank_account_id:
    )

    new_price = transaction.price.nil? ? price : (transaction.price + price)
    transaction.update(price: new_price, t_comment:)
  end

  def t_description
    "Investment #{user_bank_account.bank.bank_name} #{month_year}"
  end

  def t_comment
    "Last Day Checked: #{date.day}"
  end
  # @private_instance_methods .................................................
end
