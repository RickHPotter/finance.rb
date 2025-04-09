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

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, counter_cache: true

  # @validations ..............................................................
  validates :description, :card_installments_count, presence: true
  validate :reference_date_is_valid

  # @callbacks ................................................................
  before_validation :set_paid, on: :create
  after_initialize :build_default_card_installments
  after_save :update_associations_count_and_total
  after_destroy :update_associations_count_and_total

  # @scopes ...................................................................
  # @public_instance_methods ..................................................

  def cash_transaction_date
    due_date = date.change(day: user_card.due_date_day)
    closing_date = due_date - user_card.days_until_due_date

    return due_date if closing_date > date

    due_date + 1.month
  end

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

    reference_date = user_card.calculate_reference_date(date)
    existing_reference = Reference.find_by_reference_date(user_card, reference_date)

    if existing_reference
      self.month = existing_reference.month
      self.year = existing_reference.year
    else
      self.month = reference_date.month
      self.year = reference_date.year
      Reference.create!(user_card:, month:, year:, reference_date:)
    end

    update_installments if card_installments.any?
  end

  def update_installments
    card_installments.each_with_index do |installment, index|
      installment_date = date + index.months
      reference_date = user_card.calculate_reference_date(installment_date)

      installment.date = installment_date
      installment.month = reference_date.month
      installment.year = reference_date.year

      next if installment.new_record?

      installment.save
    end
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
    return if [ false, true ].include?(paid)

    self.paid = false
  end

  def update_associations_count_and_total
    user_card.update_card_transactions_total
    categories.each(&:update_card_transactions_count_and_total)
    entities.each(&:update_card_transactions_count_and_total)
  end

  def build_default_card_installments
    card_installments.new(number: 1, price:, date:) if card_installments.empty?
  end

  def reference_date_is_valid
    return if imported
    return false if errors.any?

    calculated_date = user_card.calculate_reference_date(date)
    errors.add(:date, "Invalid reference date") if calculated_date.month != month || calculated_date.year != year
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
