# frozen_string_literal: true

class Reference < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :skip_reference_closing_date_calculation

  # @relationships ............................................................
  belongs_to :context, optional: false
  belongs_to :user_card

  # @validations ..............................................................
  validates :context, presence: true
  validates :month, :year, :reference_date, presence: true
  validates :user_card_id, uniqueness: { scope: %i[context_id month year] }
  validates :reference_date, uniqueness: { scope: %i[context_id user_card_id] }

  # @callbacks ................................................................
  before_validation :assign_default_context
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

  def assign_default_context
    self.context ||= user_card&.user&.ensure_main_context!
  end

  def set_reference_closing_date
    return if skip_reference_closing_date_calculation

    self.reference_closing_date = if user_card.nil?
                                    reference_date - 1.day
                                  else
                                    reference_date - user_card.days_until_due_date.days
                                  end
  end

  def set_card_payment_date
    Audit::Operation.with_mutation_source(:reference_sync) { sync_card_payment_date }
  end

  def sync_card_payment_date
    card_payment = user_card.unpaid_invoices(context:).find_by(month:, year:)
    return if card_payment.nil?

    min_date = [ card_payment.cash_installments.first.date, reference_date ].compact_blank.min

    new_reference_date = reference_date.end_of_day

    card_payment.update_columns(date: new_reference_date)
    card_payment.cash_installments.first.update_columns(date: new_reference_date)

    Logic::RecalculateBalancesService.new(user: user_card.user, context:, year: min_date.year, month: min_date.month).call
  end
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: references
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  month                  :integer          not null, uniquely indexed => [context_id, user_card_id, year]
#  reference_closing_date :date             not null
#  reference_date         :date             not null, uniquely indexed => [context_id, user_card_id]
#  year                   :integer          not null, uniquely indexed => [context_id, user_card_id, month]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  context_id             :bigint           not null, uniquely indexed => [user_card_id, month, year], uniquely indexed => [user_card_id, reference_date], indexed
#  user_card_id           :bigint           not null, uniquely indexed => [context_id, month, year], uniquely indexed => [context_id, reference_date], indexed
#
# Indexes
#
#  idx_references_context_user_card_month_year      (context_id,user_card_id,month,year) UNIQUE
#  idx_references_context_user_card_reference_date  (context_id,user_card_id,reference_date) UNIQUE
#  index_references_on_context_id                   (context_id)
#  index_references_on_user_card_id                 (user_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#
