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
#  paid                   :boolean          default(FALSE)
#  money_transaction_type :string
#  installments_count     :integer          default(1), not null
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
  include Installable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, optional: true

  has_many :card_transactions
  has_many :investments
  has_many :exchanges

  # @validations ..............................................................
  validates :mt_description, :date, :starting_price, :price, :month, :year, presence: true
  validates :paid, inclusion: { in: [true, false] }

  # @callbacks ................................................................
  before_validation :set_paid, on: :create

  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # Defaults description column to a single {#to_s} call.
  #
  # @return [String] The description for an associated transactable.
  #
  def to_s
    mt_description
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets the default value for the paid field.
  #
  # @return [void]
  #
  def set_paid
    return unless date

    self.paid ||= date < Date.current
  end

  # @private_instance_methods .................................................
end
