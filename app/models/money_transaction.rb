# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                   :integer          not null, primary key
#  mt_description       :string           not null
#  mt_comment           :string
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class MoneyTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include StartingPriceCallback

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :category
  belongs_to :user_bank_account

  has_many :card_transactions
  has_many :investments

  # @validations ..............................................................
  validates :mt_description, :date, :user_id, :category_id, :starting_price,
            :user_bank_account_id, :price, :month, :year, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
