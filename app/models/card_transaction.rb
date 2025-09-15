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
  include Budgetable
  include FriendNotifiable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :duplicate

  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, counter_cache: true

  # @validations ..............................................................
  validates :description, :card_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_paid, on: :create
  after_initialize :build_default_card_installments
  after_save :update_month_year
  after_commit :update_cash_balance, :update_associations_total

  # @scopes ...................................................................
  # @class_methods ............................................................
  def self.duplicate(id)
    existing_card_transaction = find(id)

    card_transaction = existing_card_transaction.dup
    card_transaction.duplicate = true
    card_transaction.card_installments     = existing_card_transaction.card_installments.map(&:dup)
    card_transaction.category_transactions = existing_card_transaction.category_transactions.map(&:dup)

    existing_card_transaction.entity_transactions.each do |et|
      new_entity_transaction = et.dup
      new_entity_transaction.exchanges = et.exchanges.map(&:dup)
      card_transaction.entity_transactions.push(new_entity_transaction)
    end

    card_transaction
  end

  def self.new_advanced_payment(user, params)
    card_transaction = user.card_transactions.new(params)
    card_transaction.categories << user.built_in_category("CARD ADVANCE")
    card_transaction.entities << user.entities.find_or_create_by(entity_name: "CARD")

    card_transaction
  end

  # @public_instance_methods ..................................................

  # Retrieves the `reference_date` for the associated `cash_transaction` through `user_card.references`, based on `month` and `year`.
  #
  # @return [Date].
  #
  def card_payment_date
    reference = user_card.find_or_create_reference_for(date)
    reference.reference_date
  end

  # Builds `month` and `year` columns for `self` and associated `_installments`.
  #
  # @return [void].
  #
  def build_month_year
    return if user_card_id.nil?
    return if imported

    attach_reference if year.nil? && month.nil?
    update_installments
  end

  def attach_reference
    existing_reference = card_installments.first
    if existing_reference.nil?
      reference_date = user_card.calculate_reference_date(date)
      existing_reference = user_card.references.find_by(reference_date:)
    end

    if existing_reference
      self.month = existing_reference.month
      self.year = existing_reference.year
    else
      self.month = reference_date.month
      self.year = reference_date.year
      user_card.references
               .create_with(reference_closing_date: reference_date - user_card.days_until_due_date.days, reference_date:)
               .find_or_create_by(month:, year:)
    end
  end

  def update_installments
    card_installments.each_with_index do |installment, index|
      next if installment.slice(:date, :month, :year).values.compact_blank.size == 3

      installment_date = date + index.months
      reference_date = user_card.calculate_reference_date(installment_date)

      installment.date = installment_date
      installment.month = reference_date.month
      installment.year = reference_date.year

      next if installment.new_record?

      installment.save
    end
  end

  def can_be_destroyed?
    persisted?
  end

  def operation_type
    return :edit      if persisted?
    return :duplicate if duplicate

    :new
  end

  # @protected_instance_methods ...............................................

  protected

  def imported?
    imported
  end

  # @private_instance_methods .................................................

  private

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return if [ false, true ].include?(paid)

    self.paid = false
  end

  def build_default_card_installments
    card_installments.new(number: 1, price:, date:) if card_installments.empty?
  end

  def update_month_year
    return if destroyed?

    cash_transaction = card_installments.order(:year, :month, :date).first.cash_transaction
    self.year        = cash_transaction.date.year
    self.month       = cash_transaction.date.month
  end

  def update_cash_balance
    Logic::RecalculateBalancesService.new(user:, year:, month:).call and return if destroyed?

    cash_transaction = card_installments.order(:date).first.cash_transaction
    Logic::RecalculateBalancesService.new(user:, year: cash_transaction.date.year, month: cash_transaction.date.month).call
  end

  def update_associations_total
    if destroyed?
      CashTransaction.new(categories: user.categories.where(category_name: "CARD PAYMENT"), entities: user.entities.where(entity_name: user_card.user_card_name))
    else
      card_installments.first.cash_transaction
    end => cash_transaction

    Logic::RecalculateCountAndTotalService.new(card_transaction: self, cash_transaction:).call
  end
end

# == Schema Information
#
# Table name: card_transactions
#
#  id                          :bigint           not null, primary key
#  card_installments_count     :integer          default(0), not null
#  comment                     :text
#  date                        :datetime         not null
#  description                 :string           not null, indexed
#  imported                    :boolean          default(FALSE)
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null, indexed
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
#  idx_card_transactions_description_trgm                  (description) USING gin
#  idx_card_transactions_price                             (price)
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
