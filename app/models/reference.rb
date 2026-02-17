# frozen_string_literal: true

class Reference < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user_card

  # @validations ..............................................................
  validates :month, :year, :reference_date, presence: true
  validates :user_card_id, uniqueness: { scope: %i[month year] }
  validates :reference_date, uniqueness: { scope: :user_card_id }

  # @callbacks ................................................................
  before_save :set_reference_closing_date
  after_save :set_card_payment_date

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def self.find_by_month_year(month_year)
    month = month_year.month
    year = month_year.year

    find_by(month:, year:)
  end

  # @protected_instance_methods ...............................................

  protected

  def set_reference_closing_date
    self.reference_closing_date = if user_card.nil?
                                    reference_date - 1.day
                                  else
                                    reference_date - user_card.days_until_due_date.days
                                  end
  end

  def set_card_payment_date
    card_payment = user_card.unpaid_invoices.find_by(month:, year:)
    return if card_payment.nil?

    min_date = [ card_payment.cash_installments.first.date, reference_date ].compact_blank.min

    new_reference_date = card_payment.date.change(year: reference_date.year, month: reference_date.month, day: reference_date.day)

    card_payment.update_columns(date: new_reference_date)
    card_payment.cash_installments.first.update_columns(date: new_reference_date)

    Logic::RecalculateBalancesService.new(user: user_card.user, year: min_date.year, month: min_date.month).call
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: references
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  month                  :integer          not null, uniquely indexed => [user_card_id, year]
#  reference_closing_date :date             not null
#  reference_date         :date             not null
#  year                   :integer          not null, uniquely indexed => [user_card_id, month]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_card_id           :bigint           not null, uniquely indexed => [month, year], indexed
#
# Indexes
#
#  idx_references_user_card_month_year  (user_card_id,month,year) UNIQUE
#  index_references_on_user_card_id     (user_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_card_id => user_cards.id)
#
