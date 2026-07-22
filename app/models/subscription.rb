# frozen_string_literal: true

class Subscription < ApplicationRecord # rubocop:disable Metrics/ClassLength
  # @extends ..................................................................
  self.table_name = "finance_subscriptions"

  enum :status, { active: "active", paused: "paused", finished: "finished" }

  # @includes .................................................................
  include CategoryTransactable
  include EntityTransactable
  include FinancialAuditable

  audits_financial_changes skip: %i[card_transactions_count cash_transactions_count price]

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :context, optional: false
  has_many :cash_transactions, dependent: :restrict_with_exception, inverse_of: :subscription
  has_many :card_transactions, dependent: :restrict_with_exception, inverse_of: :subscription
  accepts_nested_attributes_for :cash_transactions, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :card_transactions, allow_destroy: true, reject_if: :all_blank

  # @validations ..............................................................
  validates :context, presence: true
  validates :description, :status, presence: true
  validates :price, numericality: true
  validate :validate_linked_transactions

  # @callbacks ................................................................
  before_validation :assign_default_context
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
    Audit::BulkMutation.update_columns!(self, price: cash_transactions.sum(:price) + card_transactions.sum(:price))
  end

  def can_be_destroyed?
    transactions_count.zero?
  end

  def attach_transactions!(transactions)
    subscription_category = user&.built_in_category("SUBSCRIPTION")

    Array(transactions).each do |transaction|
      sync_attached_transaction!(transaction, subscription_category:)
    end

    refresh_price!
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def assign_default_context
    self.context ||= user&.ensure_main_context!
  end

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

    mark_destroying_transactions_as_confirmed(cash_transactions)
    mark_destroying_transactions_as_confirmed(card_transactions)

    sync_transactions(cash_transactions.reject(&:marked_for_destruction?), subscription_category)
    sync_transactions(card_transactions.reject(&:marked_for_destruction?), subscription_category)
  end

  def sync_transactions(transactions, subscription_category)
    transactions.each do |transaction|
      if metadata_only_linked_transaction_sync?(transaction)
        sync_transaction_metadata(transaction)
        next
      end

      next if skip_linked_transaction_sync?(transaction)

      sync_transaction_metadata(transaction)

      sync_transaction_categories(transaction, subscription_category)
      sync_transaction_entities(transaction)
      sync_transaction_installments(transaction)
      sync_transaction_month_year(transaction)
    end
  end

  def mark_destroying_transactions_as_confirmed(transactions)
    transactions.select(&:marked_for_destruction?).each do |transaction|
      next unless transaction.respond_to?(:historical_correction_confirmation=)

      transaction.historical_correction_confirmation = true
    end
  end

  def skip_linked_transaction_sync?(transaction)
    return false if transaction.new_record? || transaction.marked_for_destruction?
    return false if transaction.changed?
    return false if subscription_metadata_changed?
    return false if subscription_allocation_changed?

    true
  end

  def metadata_only_linked_transaction_sync?(transaction)
    return false if transaction.new_record? || transaction.marked_for_destruction?
    return false if transaction.changed?
    return false unless subscription_metadata_changed?
    return false if subscription_allocation_changed?

    true
  end

  def subscription_metadata_changed? = will_save_change_to_description? || will_save_change_to_comment?

  def sync_transaction_metadata(transaction)
    original_description = transaction.description
    transaction.user = user
    transaction.context = context if transaction.respond_to?(:context=)
    transaction.subscription = self
    transaction.description = description
    transaction.comment = synced_transaction_comment(transaction, original_description)
  end

  def synced_transaction_comment(transaction, original_description)
    return comment if transaction.new_record?
    return transaction.comment if original_description.blank? || original_description == description

    appended_original_description_comment(transaction.comment, original_description)
  end

  def subscription_allocation_changed?
    association_ids_changed?(original_categories, category_transactions, :category_id) ||
      association_ids_changed?(original_entities, entity_transactions, :entity_id)
  end

  def association_ids_changed?(original_ids, association_records, foreign_key)
    return false if original_ids.blank?

    Array(original_ids).map(&:to_i).sort != association_records.map(&foreign_key).compact.map(&:to_i).sort
  end

  def sync_attached_transaction!(transaction, subscription_category:)
    original_description = transaction.description

    transaction.user = user
    transaction.context = context if transaction.respond_to?(:context=)
    transaction.subscription = self
    transaction.description = description
    transaction.comment = appended_original_description_comment(transaction.comment, original_description)
    transaction.historical_correction_confirmation = true if transaction.respond_to?(:historical_correction_confirmation=)
    transaction.skip_subscription_installment_sync = true if transaction.respond_to?(:skip_subscription_installment_sync=)

    attach_missing_subscription_categories(transaction, subscription_category)
    transaction.entity_ids = [ *transaction.entity_ids, *entity_ids ].compact.uniq

    transaction.save!
  end

  def attach_missing_subscription_categories(transaction, subscription_category)
    existing_category_ids = transaction.category_transactions.reject(&:marked_for_destruction?).filter_map(&:category_id).map(&:to_i)
    desired_category_ids = [ *category_ids, subscription_category&.id ].compact.map(&:to_i).uniq

    (desired_category_ids - existing_category_ids).each do |category_id|
      transaction.category_transactions.build(category_id:)
    end
  end

  def appended_original_description_comment(current_comment, original_description)
    [ current_comment, original_description ].compact_blank.uniq.join("\n")
  end

  def sync_transaction_categories(transaction, subscription_category)
    transaction.categories = [ *categories, subscription_category ].compact.uniq(&:id)
  end

  def sync_transaction_entities(transaction)
    transaction.entities = entities.to_a.uniq(&:id)
  end

  def sync_transaction_installments(transaction)
    case transaction
    when CashTransaction
      installment = transaction.cash_installments.first || transaction.cash_installments.build
      month       = transaction.date&.month || transaction.month
      year        = transaction.date&.year || transaction.year
    when CardTransaction
      installment = transaction.card_installments.first || transaction.card_installments.build
      month       = transaction.month
      year        = transaction.year
    end

    installment.assign_attributes(
      number: 1,
      price: transaction.price,
      starting_price: transaction.price,
      date: transaction.date,
      month:,
      year:,
      paid: transaction.paid
    )
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
    validate_card_transactions_presence
    validate_cash_transactions_safety
    validate_card_transactions_safety
  end

  def validate_card_transactions_presence
    card_transactions.reject(&:marked_for_destruction?).each do |transaction|
      next if transaction.user_card_id.present?

      transaction.errors.add(:user_card_id, :blank)
      errors.add(:base, :invalid)
    end
  end

  def validate_cash_transactions_safety
    cash_transactions.reject(&:marked_for_destruction?).each do |transaction|
      next if transaction.errors.any?
      next if skip_linked_transaction_validation?(transaction)

      errors.add(:base, :invalid) unless transaction.valid?
    end
  end

  def validate_card_transactions_safety
    card_transactions.reject(&:marked_for_destruction?).each do |transaction|
      next if transaction.errors.any?
      next if skip_linked_transaction_validation?(transaction)

      errors.add(:base, :invalid) unless transaction.valid?
    end
  end

  def skip_linked_transaction_validation?(transaction)
    transaction.persisted? && !transaction.changed? && !subscription_allocation_changed?
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
#  context_id              :bigint           not null, indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_context_id  (context_id)
#  index_finance_subscriptions_on_status      (status)
#  index_finance_subscriptions_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
