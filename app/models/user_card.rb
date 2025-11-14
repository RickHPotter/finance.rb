# frozen_string_literal: true

class UserCard < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :current_closing_date, :current_due_date

  # @relationships ............................................................
  belongs_to :user
  belongs_to :card

  has_many :card_transactions
  has_many :card_installments, through: :card_transactions
  has_many :card_installments_invoices, lambda {
    joins(:categories).where(categories: { category_name: "CARD PAYMENT" }).distinct
  }, through: :card_installments, source: :cash_transaction

  has_many :cash_transactions

  has_many :references, dependent: :destroy

  # @validations ..............................................................
  validates :user_card_name, :due_date_day, :days_until_due_date, :min_spend, :credit_limit, presence: true
  validates :user_card_name, uniqueness: { scope: %i[user_id card_id] }

  # @callbacks ................................................................
  before_validation :set_user_card_name, on: :create
  after_update :update_references_and_payments, if: :payment_date_settings_changed?

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def find_or_create_reference_for(date)
    reference_date = calculate_reference_date(date)
    reference = references.find_by(month: reference_date.month, year: reference_date.year)
    return reference if reference.present?

    references.create(
      month: reference_date.month,
      year: reference_date.year,
      reference_closing_date: reference_date - days_until_due_date.days,
      reference_date:
    )
  end

  def calculate_reference_date(transaction_date)
    due_date = transaction_date.change(day: due_date_day)
    due_date = (due_date + 1.month) if transaction_date >= due_date
    closing_date = due_date - days_until_due_date.days

    return due_date if closing_date > transaction_date

    due_date + 1.month
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

  # @private_instance_methods .................................................

  private

  def payment_date_settings_changed?
    saved_change_to_due_date_day? || saved_change_to_days_until_due_date?
  end

  # After a card's payment settings are updated, this method adjusts the dates of all
  # associated unpaid invoices and exchange-related transactions to align with the new
  # billing cycle. It ensures that financial records remain consistent and accurate.
  def update_references_and_payments
    return if current_due_date.nil?

    update_unpaid_card_payments
    update_unpaid_exchange_installments

    Logic::RecalculateBalancesService.new(user:).call
  end

  def update_unpaid_card_payments
    unpaid_invoices.find_each do |card_payment|
      new_reference_date = calculate_new_reference_date_for(card_payment.month, card_payment.year)

      ApplicationRecord.transaction do
        card_payment.update!(date: new_reference_date.end_of_day)
        card_payment.cash_installments.first&.update!(date: new_reference_date.end_of_day)
      end
    end
  end

  def unpaid_invoices
    card_installments_invoices.where(paid: false).distinct
  end

  def update_unpaid_exchange_installments
    unpaid_exchange_installments.find_each do |cash_installment|
      new_reference_date = calculate_new_reference_date_for(cash_installment.month, cash_installment.year)
      cash_transaction = cash_installment.cash_transaction
      exchanges = cash_transaction.exchanges.card_bound

      next if exchanges.empty?

      ApplicationRecord.transaction do
        cash_installment.update!(date: new_reference_date)
        cash_transaction.update!(date: new_reference_date)
        exchanges.each { |exchange| exchange.update!(date: new_reference_date) }
      end
    end
  end

  def unpaid_exchange_installments
    user.cash_installments
        .joins(cash_transaction: :categories)
        .where(
          paid: false,
          cash_transaction: {
            user_card_id: id,
            categories: { built_in: true, category_name: "EXCHANGE RETURN" }
          }
        )
  end

  def calculate_new_reference_date_for(month, year)
    references.find_by(month:, year:)&.destroy

    this_month_due_date = current_due_date.change(month:, year:)
    date_within_previous_cycle = this_month_due_date - days_until_due_date.days - 1.day

    find_or_create_reference_for(date_within_previous_cycle).reference_date
  end
end

# == Schema Information
#
# Table name: user_cards
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  credit_limit            :integer          not null
#  days_until_due_date     :integer          not null
#  due_date_day            :integer          default(1), not null
#  min_spend               :integer          not null
#  user_card_name          :string           not null, uniquely indexed => [user_id, card_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_id                 :bigint           not null, indexed, uniquely indexed => [user_id, user_card_name]
#  user_id                 :bigint           not null, uniquely indexed => [card_id, user_card_name], indexed
#
# Indexes
#
#  index_user_cards_on_card_id           (card_id)
#  index_user_cards_on_on_composite_key  (user_id,card_id,user_card_name) UNIQUE
#  index_user_cards_on_user_id           (user_id)
#
