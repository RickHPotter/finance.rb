# frozen_string_literal: true

class CashTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasCashInstallments
  include CategoryTransactable
  include EntityTransactable
  include Budgetable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :flag_for_balance_recalculation

  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, counter_cache: true, optional: true

  has_many :card_installments, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :exchanges

  # @validations ..............................................................
  validates :description, :cash_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_paid, on: :create
  after_initialize :build_default_cash_installments
  before_save :set_flag_for_balance_recalculation
  after_destroy :trigger_balance_recalculation
  after_commit :trigger_balance_recalculation, on: %i[create update], if: :flag_for_balance_recalculation
  after_commit :update_associations_total

  # @scopes ...................................................................
  # @public_instance_methods ..................................................

  def entity_bundle
    return user_card.user_card_name if categories.pluck(:category_name).intersect?([ "CARD ADVANCE", "CARD PAYMENT" ])

    entities.order(:entity_name).pluck(:entity_name).join(", ")
  end

  # Builds `month` and `year` columns for `self` and associated `_installments`.
  #
  # @return [void].
  #
  def build_month_year
    return if imported

    self.date ||= Time.zone.today

    set_month_year
    update_installments
  end

  def update_installments
    cash_installments.each_with_index do |installment, index|
      installment.date = date + index.months
      installment.month = installment.date.month
      installment.year = installment.date.year
    end
  end

  def can_be_updated?
    !categories.pluck(:category_name).intersect?([ "CARD PAYMENT", "INVESTMENT" ])
  end

  def can_be_deleted?
    !categories.pluck(:category_name).intersect?([ "CARD PAYMENT", "CARD INSTALLMENT", "INVESTMENT", "EXCHANGE RETURN" ])
  end

  def investment?
    cash_transaction_type == "Investment"
  end

  def card_payment?
    categories.pluck(:category_name).include? "CARD PAYMENT"
  end

  def card_advance?
    categories.pluck(:category_name).include? "CARD ADVANCE"
  end

  def exchange_return?
    categories.pluck(:category_name).include?("EXCHANGE RETURN")
  end

  def can_be_destroyed?
    persisted? && categories.exclude?(user.built_in_category("EXCHANGE RETURN"))
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def build_default_cash_installments
    cash_installments.new(number: 1, price:, date:) if cash_installments.empty?
  end

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return if [ false, true ].include?(paid)

    self.paid = cash_transaction_type == "Investment"
  end

  def set_flag_for_balance_recalculation
    return if imported

    cash_transaction_changes = changes.slice(:price, :date).present?
    cash_installments_changes = cash_installments.any? { |i| i.changes.slice(:price, :date).present? }
    cash_installments_count_change = cash_installments.count != cash_installments.size

    self.flag_for_balance_recalculation = cash_transaction_changes || cash_installments_changes || cash_installments_count_change
  end

  def trigger_balance_recalculation
    Logic::RecalculateBalancesService.new(user:, year: date.year, month: date.month).call
  end

  def update_associations_total
    Logic::RecalculateCountAndTotalService.new(cash_transaction: self).call
  end
end

# == Schema Information
#
# Table name: cash_transactions
#
#  id                      :bigint           not null, primary key
#  cash_installments_count :integer          default(0), not null
#  cash_transaction_type   :string
#  comment                 :text
#  date                    :datetime         not null
#  description             :string           not null
#  imported                :boolean          default(FALSE)
#  month                   :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_bank_account_id    :bigint           indexed
#  user_card_id            :bigint           indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_user_bank_account_id  (user_bank_account_id)
#  index_cash_transactions_on_user_card_id          (user_card_id)
#  index_cash_transactions_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
