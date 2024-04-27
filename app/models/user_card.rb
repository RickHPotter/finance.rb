# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id                   :bigint           not null, primary key
#  user_card_name       :string           not null
#  days_until_due_date  :integer          not null
#  current_due_date     :date             not null
#  current_closing_date :date             not null
#  min_spend            :decimal(, )      not null
#  credit_limit         :decimal(, )      not null
#  active               :boolean          not null
#  user_id              :bigint           not null
#  card_id              :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class UserCard < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include ActiveCallback
  include MonthYear

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :card

  has_many :card_transactions

  # @validations ..............................................................
  validates :user_card_name, :current_due_date, :current_closing_date,
            :days_until_due_date, :min_spend, :credit_limit, :active, presence: true
  validates :user_card_name, uniqueness: { scope: :user_id }

  # @callbacks ................................................................
  before_validation :set_user_card_name, on: :create
  before_validation :set_current_dates

  # @scopes ...................................................................
  scope :active, -> { where(active: true) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets `user_card_name` in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_user_card_name
    self.user_card_name ||= card.card_name
  end

  # Sets the `current_closing_date` and `current_due_date` attributes based on `days_until_due_date`.
  #
  # @example
  #   credit_card = CreditCard.new(current_due_date: Date.new(2023, 12, 1), days_until_due_date: 3)
  #   # considering today is not before `current_due_date` (2023-12-01 or after)
  #   p "#{credit_card.current_closing_date} <-> #{credit_card.current_due_date}"
  #   => 2023-12-28 <-> 2024-01-01
  #
  # @example
  #   credit_card = CreditCard.new(current_due_date: Date.new(2023, 12, 1), days_until_due_date: 3)
  #   # considering today is before `current_due_date` (2023-12-01)
  #   p "#{credit_card.current_closing_date} <-> #{credit_card.current_due_date}"
  #   => 2023-11-28 <-> 2023-12-01
  #
  # @note This is a method that is called before_validation.
  # @note The method returns false if `current_due_date` or `days_until_due_date` is nil.
  #
  # @see {MonthYear#next_date}
  #
  # @return [Boolean]
  #
  def set_current_dates
    return false if current_due_date.nil? || days_until_due_date.nil?

    self.current_due_date = next_date(days: current_due_date.day)
    self.current_closing_date = current_due_date - days_until_due_date
  end

  # @private_instance_methods .................................................
end
