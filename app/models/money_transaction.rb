# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                     :bigint           not null, primary key
#  mt_description         :string           not null
#  mt_comment             :text
#  date                   :date             not null
#  month                  :integer          not null
#  year                   :integer          not null
#  starting_price         :decimal(, )      not null
#  price                  :decimal(, )      not null
#  money_transaction_type :string
#  user_id                :bigint           not null
#  user_card_id           :bigint
#  user_bank_account_id   :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class MoneyTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include StartingPriceCallback
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, optional: true

  has_many :card_transactions
  has_many :investments

  # @validations ..............................................................
  validates :mt_description, :date, :user_id, :starting_price,
            :price, :month, :year, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  def to_s
    mt_description
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
