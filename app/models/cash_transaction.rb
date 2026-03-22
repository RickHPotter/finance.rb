# frozen_string_literal: true

class CashTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasCashInstallments
  include CategoryTransactable
  include EntityTransactable
  include HasSubscription
  include Budgetable
  include FriendNotifiable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :min_date, :duplicate, :edit_phase, :skip_recalculate_balance, :friend_notification_intent, :source_message_id

  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, counter_cache: true, optional: true
  belongs_to :investment_type, optional: true
  belongs_to :reference_transactable, polymorphic: true, optional: true

  has_many :card_installments, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :exchanges

  # @validations ..............................................................
  validates :description, :cash_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_paid, on: :create
  after_initialize :build_default_cash_installments
  after_save :sync_subscription_installment, :set_min_date
  after_commit :update_cash_balance, :update_associations_total

  # @scopes ...................................................................
  scope :investment, -> { where(cash_transaction_type: "Investment") }
  scope :card_payment, -> { where(cash_transaction_type: "CardInstallment") }
  scope :card_advance, -> { where(cash_transaction_type: "CardTransaction") }
  scope :exchange_return, -> { where(cash_transaction_type: "Exchange") }

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
    update_installments if new_record?
  end

  def update_installments
    cash_installments.each_with_index do |installment, index|
      next if installment.paid?

      installment.date ||= date + index.months
      installment.month ||= installment.date.month
      installment.year ||= installment.date.year
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
    return categories.pluck(:category_name).include? "CARD PAYMENT" if persisted?

    cash_transaction_type == "CardInstallment"
  end

  def card_advance?
    categories.pluck(:category_name).include? "CARD ADVANCE"

    cash_transaction_type == "CardTransaction"
  end

  def exchange_return?
    return true if persisted? && categories.pluck(:category_name).include?("EXCHANGE RETURN")
    return true if destroyed? && original_categories.include?(user.categories.where(category_name: "EXCHANGE RETURN").first.id)

    cash_transaction_type == "Exchange"
  end

  def borrow_return?
    return true if persisted? && categories.pluck(:category_name).include?("BORROW RETURN")
    return true if destroyed? && original_categories.include?(user.categories.where(category_name: "BORROW RETURN").first.id)

    reference_transactable&.user_id != user.id
  end

  def can_be_destroyed?
    return false if card_payment? || card_advance? || exchange_return?

    persisted?
  end

  def installments
    cash_installments
  end

  def installments_count
    cash_installments_count
  end

  def effective_friend_notification_intent
    return friend_notification_intent if friend_notification_intent.present?

    latest_friend_notification_intent
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def latest_friend_notification_intent
    return if new_record?

    headers = Message.where(reference_transactable: self, user:)
                     .where(superseded_by_id: nil)
                     .where.not(headers: [ nil, "" ])
                     .order(created_at: :desc)
                     .pick(:headers)

    return if headers.blank?

    payload = JSON.parse(headers)

    payload["intent"] || payload.dig("replay", "intent")
  rescue JSON::ParserError
    nil
  end

  def build_default_cash_installments
    cash_installments.new(number: 1, price:, date:) if cash_installments.empty?
  end

  def sync_subscription_installment
    return if subscription_id.blank? || cash_installments_count != 1

    cash_installments.first&.update_columns(
      price:,
      starting_price: price,
      date:,
      month:,
      year:
    )
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

  def set_min_date
    self.min_date = [
      *changes[:date],
      *previous_changes[:date],
      cash_installments.order(:date).first.date.beginning_of_month,
      Date.new(changes[:year]&.min || year, changes[:month]&.min || month)
    ].compact_blank.min
  end

  def update_cash_balance
    return if skip_recalculate_balance

    Logic::RecalculateBalancesService.new(user:, year: date.year, month: date.month).call and return if destroyed?

    self.min_date ||= cash_installments.order(:date).first.date.beginning_of_month
    Logic::RecalculateBalancesService.new(user:, year: min_date.year, month: min_date.month).call
  end

  def update_associations_total
    return if destroyed?

    Logic::RecalculateCountAndTotalService.new(cash_transaction: self).call
  end
end

# == Schema Information
#
# Table name: cash_transactions
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  cash_installments_count     :integer          default(0), not null
#  cash_transaction_type       :string
#  comment                     :text
#  date                        :datetime         not null
#  description                 :string           not null
#  imported                    :boolean          default(FALSE)
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null
#  reference_transactable_type :string           indexed => [reference_transactable_id], uniquely indexed => [reference_transactable_id]
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  investment_type_id          :bigint           indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type], uniquely indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_bank_account_id        :bigint           indexed
#  user_card_id                :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_investment_type_id       (investment_type_id)
#  index_cash_transactions_on_reference_transactable   (reference_transactable_type,reference_transactable_id)
#  index_cash_transactions_on_subscription_id          (subscription_id)
#  index_cash_transactions_on_user_bank_account_id     (user_bank_account_id)
#  index_cash_transactions_on_user_card_id             (user_card_id)
#  index_cash_transactions_on_user_id                  (user_id)
#  index_reference_transactable_on_cash_composite_key  (reference_transactable_type,reference_transactable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (subscription_id => finance_subscriptions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
