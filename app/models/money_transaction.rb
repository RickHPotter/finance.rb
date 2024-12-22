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
#  starting_price         :integer          not null
#  price                  :integer          not null
#  paid                   :boolean          default(FALSE)
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
  include HasMonthYear
  include HasStartingPrice
  include CategoryTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, optional: true

  has_many :installments, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :exchanges, dependent: :destroy

  # @validations ..............................................................
  validates :mt_description, :date, :month, :year, :starting_price, :price, presence: true
  validates :paid, inclusion: { in: [ true, false ] }

  # @callbacks ................................................................
  before_validation :set_paid, on: :create

  # @scopes ...................................................................
  scope :by_user, ->(user) { where(user:) }

  # @public_instance_methods ..................................................

  # Defaults `mt_description` column to a single {#to_s} call.
  #
  # @return [String] The description for an associated `transactable`.
  #
  def to_s
    mt_description
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return unless date

    self.paid ||= date < Date.current
  end

  # @private_instance_methods .................................................
end
