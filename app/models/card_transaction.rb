# frozen_string_literal: true

class CardTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasCardInstallments
  include CategoryTransactable
  include EntityTransactable
  include HasAdvancePayments

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :imported

  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card

  # @validations ..............................................................
  validates :description, :card_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_paid, on: :create

  # @scopes ...................................................................
  # @public_instance_methods ..................................................

  # Generates a `date` for the associated `cash_transaction` through `installment`, based on `user_card.current_due_date` and `user_card.current_closing_date`.
  #
  # @return [Date].
  #
  def cash_transaction_date
    closing_days      = user_card.current_closing_date.day
    next_closing_date = next_date(date:, days: closing_days)
    next_due_date     = next_closing_date + user_card.days_until_due_date

    return next_due_date if next_closing_date > date

    next_date(date: next_due_date, months: 1)
  end

  # Builds `month` and `year` columns for `self` and associated `_installments`.
  #
  # @return [void].
  #
  def build_month_year
    self.date ||= Date.current unless imported
    set_month_year
    card_installments.each(&:build_month_year)
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return if paid.present?

    self.paid = false
  end
end

# == Schema Information
#
# Table name: card_transactions
#
#  id                          :bigint           not null, primary key
#  card_installments_count     :integer          default(0), not null
#  comment                     :text
#  date                        :date             not null
#  description                 :string           not null
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  advance_cash_transaction_id :bigint           indexed
#  user_card_id                :bigint           not null, indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_card_transactions_on_advance_cash_transaction_id  (advance_cash_transaction_id)
#  index_card_transactions_on_user_card_id                 (user_card_id)
#  index_card_transactions_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (advance_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
