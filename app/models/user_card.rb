# frozen_string_literal: true

class UserCard < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :card

  has_many :card_transactions
  has_many :card_installments, through: :card_transactions
  has_many :card_installments_invoices, lambda {
    joins(:categories).where(categories: { category_name: "CARD PAYMENT" }).distinct
  }, through: :card_installments, source: :cash_transaction
  has_many :cash_transactions

  # @validations ..............................................................
  validates :user_card_name, :current_due_date, :current_closing_date, :days_until_due_date, :min_spend, :credit_limit, presence: true
  validates :user_card_name, uniqueness: { scope: :user_id }

  # @callbacks ................................................................
  before_validation :set_user_card_name, on: :create
  before_validation :set_current_dates, if: -> { active? }

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def update_card_transactions_total
    update_columns(card_transactions_total: card_transactions.sum(:price))
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets `user_card_name` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_user_card_name
    self.user_card_name ||= card.card_name
  end

  # Sets the `current_closing_date` and `current_due_date` attributes based on `current_due_date` and `days_until_due_date`.
  #
  # @note This is a method that is called before_validation.
  # @note The method returns false if `current_due_date` or `days_until_due_date` is nil.
  #
  # @see {MonthYear#next_date}.
  #
  # @return [Boolean].
  #
  def set_current_dates
    fields_that_are_not_nil = [ current_closing_date, days_until_due_date, current_due_date ].compact
    return if fields_that_are_not_nil.count < 2

    update_dates

    self.current_closing_date ||= current_due_date - days_until_due_date
    self.days_until_due_date  ||= (current_due_date - current_closing_date).abs
    self.current_due_date     ||= next_date(days: current_due_date.day)
  end

  def update_dates
    self.current_closing_date = current_closing_date + 1.month if current_closing_date && current_closing_date < Date.current
    self.current_due_date     = current_due_date     + 1.month if current_due_date     && current_due_date     < Date.current
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: user_cards
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  credit_limit            :integer          not null
#  current_closing_date    :date             not null
#  current_due_date        :date             not null
#  days_until_due_date     :integer          not null
#  min_spend               :integer          not null
#  user_card_name          :string           not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_id                 :bigint           not null, indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_user_cards_on_card_id         (card_id)
#  index_user_cards_on_user_card_name  (user_card_name) UNIQUE
#  index_user_cards_on_user_id         (user_id)
#
