# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :bigint           not null, primary key
#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :bigint           not null
#  user_card_id       :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class CardTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasInstallments
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card

  # @validations ..............................................................
  validates :date, :ct_description, :month, :year, presence: true
  validates :starting_price, :price, :installments_count, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_user_card, ->(user_card_id, user_id) { where(user_card_id:).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }

  # @public_instance_methods ..................................................

  # Defaults `ct_description` column to a single {#to_s} call.
  #
  # @return [String] The description for an associated `transactable`.
  #
  def to_s
    ct_description
  end

  # Generates a `date` for the associated `money_transaction` through `installment`, based on `user_card.current_due_date` and `user_card.current_closing_date`.
  #
  # @return [Date].
  #
  def money_transaction_date
    closing_days = user_card.current_closing_date.day
    due_days     = user_card.current_due_date.day

    next_closing_date = next_date(date:, days: closing_days)
    next_due_date     = next_date(date:, days: due_days)

    return next_due_date if next_closing_date > date

    next_date(date: next_due_date, months: 1)
  end

  # Builds `month` and `year` columns for `self` and associated `installments`.
  #
  # @return [void].
  #
  def build_month_year
    set_month_year
    installments.each(&:build_month_year)
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
