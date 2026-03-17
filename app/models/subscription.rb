# frozen_string_literal: true

class Subscription < ApplicationRecord
  # @extends ..................................................................
  self.table_name = "finance_subscriptions"

  enum :status, { active: "active", paused: "paused", finished: "finished" }

  # @includes .................................................................
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  has_many :cash_transactions, dependent: :restrict_with_exception, inverse_of: :subscription
  has_many :card_transactions, dependent: :restrict_with_exception, inverse_of: :subscription
  accepts_nested_attributes_for :cash_transactions, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :card_transactions, allow_destroy: true, reject_if: :all_blank

  # @validations ..............................................................
  validates :description, :status, presence: true
  validates :price, numericality: true
  validate :validate_linked_transactions

  # @callbacks ................................................................
  before_validation :set_defaults, on: :create
  before_validation :prepare_linked_transactions

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  def transactions
    [ *cash_transactions_scope, *card_transactions_scope ].sort_by(&:date)
  end

  def transactions_count
    cash_transactions_count + card_transactions_count
  end

  def category_id
    category_transactions.first&.category_id
  end

  def entity_id
    entity_transactions.first&.entity_id
  end

  def refresh_price!
    update_columns(price: cash_transactions.sum(:price) + card_transactions.sum(:price))
  end

  def can_be_destroyed?
    transactions_count.zero?
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def cash_transactions_scope
    persisted? ? CashTransaction.where(subscription_id: id) : cash_transactions
  end

  def card_transactions_scope
    persisted? ? CardTransaction.where(subscription_id: id) : card_transactions
  end

  def set_defaults
    self.status ||= :active
  end

  def prepare_linked_transactions
    subscription_category = user&.built_in_category("SUBSCRIPTION")

    sync_transactions(cash_transactions.reject(&:marked_for_destruction?), subscription_category)
    sync_transactions(card_transactions.reject(&:marked_for_destruction?), subscription_category)
  end

  def sync_transactions(transactions, subscription_category)
    transactions.each do |transaction|
      transaction.user = user
      transaction.subscription = self
      transaction.description = description
      transaction.comment = comment

      sync_transaction_categories(transaction, subscription_category)
      sync_transaction_entities(transaction)
      sync_transaction_installments(transaction)
      sync_transaction_month_year(transaction)
    end
  end

  def sync_transaction_categories(transaction, subscription_category)
    transaction.categories = [ *categories, subscription_category ].compact.uniq
  end

  def sync_transaction_entities(transaction)
    transaction.entities = entities.to_a
  end

  def sync_transaction_installments(transaction)
    case transaction
    when CashTransaction
      installment = transaction.cash_installments.first || transaction.cash_installments.build
      installment.assign_attributes(
        number: 1,
        price: transaction.price,
        starting_price: transaction.price,
        date: transaction.date,
        month: transaction.date&.month || transaction.month,
        year: transaction.date&.year || transaction.year,
        paid: transaction.paid
      )
    when CardTransaction
      installment = transaction.card_installments.first || transaction.card_installments.build
      installment.assign_attributes(
        number: 1,
        price: transaction.price,
        starting_price: transaction.price,
        date: transaction.date,
        month: transaction.month,
        year: transaction.year,
        paid: transaction.paid
      )
    end
  end

  def sync_transaction_month_year(transaction)
    return if transaction.date.blank?

    if transaction.is_a?(CashTransaction)
      transaction.month = transaction.date.month
      transaction.year = transaction.date.year
    elsif transaction.user_card_id.present? && (transaction.month.blank? || transaction.year.blank?)
      transaction.build_month_year
    end
  end

  def validate_linked_transactions
    cash_transactions.reject(&:marked_for_destruction?).each do |transaction|
      next if transaction.user_bank_account_id.present?

      transaction.errors.add(:user_bank_account_id, :blank)
      errors.add(:base, :invalid)
    end

    card_transactions.reject(&:marked_for_destruction?).each do |transaction|
      next if transaction.user_card_id.present?

      transaction.errors.add(:user_card_id, :blank)
      errors.add(:base, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: finance_subscriptions
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  card_transactions_count :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  comment                 :text
#  description             :string           not null
#  price                   :integer          default(0), not null
#  status                  :string           default("active"), not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_status   (status)
#  index_finance_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
