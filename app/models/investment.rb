# frozen_string_literal: true

class Investment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include CashTransactable
  include CategoryTransactable
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :min_date, :duplicate

  # @relationships ............................................................
  belongs_to :user
  belongs_to :context, optional: false
  belongs_to :user_bank_account
  belongs_to :investment_type
  belongs_to :piggy_bank_return_cash_transaction,
             class_name: "CashTransaction",
             optional: true,
             inverse_of: :piggy_bank_investments

  # @validations ..............................................................
  validates :context, presence: true
  validates :price, :date, :description, presence: true
  validates :price, numericality: { greater_than: 0 }, unless: :piggy_bank_valuation?
  validates :price, numericality: { other_than: 0 }, if: :piggy_bank_valuation?
  validate :validate_piggy_bank_return_group
  validate :validate_piggy_bank_return_immutability, on: :update
  validate :validate_piggy_bank_projection_amount, if: :piggy_bank_valuation?

  # @callbacks ................................................................
  before_validation :assign_default_context
  before_destroy :prevent_invalid_piggy_bank_projection_destroy
  after_save :set_min_date
  after_save :sync_piggy_bank_return_projection, if: :piggy_bank_valuation?
  after_destroy :sync_piggy_bank_return_projection, if: :piggy_bank_valuation?
  after_commit :update_cash_balance, :update_associations_total

  # @scopes ...................................................................
  # @public_instance_methods ..................................................

  # Generates a `description` for the associated `cash_transaction` based on the `user`'s `bank_name` and `month_year`.
  #
  # @return [String] The generated description.
  #
  def cash_transaction_description
    [
      investment_type&.display_name&.upcase,
      user_bank_account.user_bank_account_name,
      month_year
    ].compact_blank.join(" ")
  end

  # Generates a `date` for the associated `cash_transaction`, picking the end of given `month` for the `cash_transaction`.
  #
  # @return [Date].
  #
  def card_payment_date
    beginning_of_month
  end

  # Generates a comment for the associated `cash_transaction` based on investment days.
  #
  # @return [String] The generated comment.
  #
  def comment
    days = I18n.t("datetime.prompts.day").pluralize
    "#{days}: [#{cash_transaction.investments.order(:date).map(&:day).join(', ')}]"
  end

  def piggy_bank_valuation?
    piggy_bank_return_cash_transaction_id.present?
  end

  # @protected_instance_methods ...............................................

  protected

  # Generates a `category_transactions` for the associated `cash_transaction` that mounts up the investment entries.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions
    { category_id: user.built_in_category("INVESTMENT").id }
  end

  # Generates a `category_transactions_attributes` for the associated `cash_transaction` that mounts up the investment entries.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions_attributes
    category_transactions.merge(id: nil)
  end

  # Generates a `entity_transactions_attributes` for the associated `cash_transaction` that mounts up the investment entries.
  #
  # @return [Hash] The generated attributes.
  #
  def entity_transactions_attributes
    [ { id: nil, is_payer: false, price: 0, entity_id: user.entities.find_or_create_by(entity_name: user_bank_account.user_bank_account_name).id } ]
  end

  # @private_instance_methods .................................................

  private

  def assign_default_context
    self.context ||= user&.ensure_main_context!
  end

  def set_min_date
    self.min_date = [
      *changes[:date],
      *previous_changes[:date],
      cash_transaction&.date&.beginning_of_month,
      Date.new(changes[:year]&.min || year, changes[:month]&.min || month)
    ].compact_blank.min
  end

  def update_cash_balance
    return if piggy_bank_valuation?

    Logic::RecalculateBalancesService.new(user:, context:, year: date.year, month: date.month).call and return if destroyed?

    self.min_date ||= date
    Logic::RecalculateBalancesService.new(user:, context:, year: min_date.year, month: min_date.month).call
  end

  def update_associations_total
    return if destroyed? || piggy_bank_valuation?

    Logic::RecalculateCountAndTotalService.new(cash_transaction:).call
  end

  def protect_paid_cash_transaction_projection?
    false
  end

  def skip_cash_transaction_projection?
    piggy_bank_valuation?
  end

  def validate_piggy_bank_return_group
    return unless piggy_bank_valuation?

    target = piggy_bank_return_cash_transaction
    errors.add(:piggy_bank_return_cash_transaction, :invalid) and return if target.blank?

    errors.add(:piggy_bank_return_cash_transaction, :invalid) unless target.user_id == user_id && target.context_id == context_id
    errors.add(:piggy_bank_return_cash_transaction, :invalid) unless target.generated_piggy_bank_return?
    return unless new_record? || will_save_change_to_piggy_bank_return_cash_transaction_id?

    errors.add(:piggy_bank_return_cash_transaction, :closed) unless target.piggy_bank_group_open?
  end

  def validate_piggy_bank_return_immutability
    return unless will_save_change_to_piggy_bank_return_cash_transaction_id?

    errors.add(:piggy_bank_return_cash_transaction, :immutable)
  end

  def validate_piggy_bank_projection_amount
    target = piggy_bank_return_cash_transaction
    return if target.blank? || target.piggy_bank_return_links.blank?

    principal = target.piggy_bank_return_links.sum(:return_price)
    other_deltas = target.piggy_bank_investments.where.not(id:).sum(:price)
    projected_total = principal + other_deltas + price.to_i
    paid_total = target.cash_installments.where(paid: true).sum(:price)
    return if projected_total.positive? && projected_total > paid_total

    errors.add(:price, :piggy_bank_projection_non_positive)
  end

  def sync_piggy_bank_return_projection
    piggy_bank_return_cash_transaction.piggy_bank_return_links.first&.sync_return_projection!
  end

  def prevent_invalid_piggy_bank_projection_destroy
    return unless piggy_bank_valuation?

    target = piggy_bank_return_cash_transaction
    principal = target.piggy_bank_return_links.sum(:return_price)
    remaining_deltas = target.piggy_bank_investments.where.not(id:).sum(:price)
    paid_total = target.cash_installments.where(paid: true).sum(:price)
    return if principal + remaining_deltas > paid_total

    errors.add(:base, :piggy_bank_paid_history_locked)
    throw(:abort)
  end
end

# == Schema Information
#
# Table name: investments
# Database name: primary
#
#  id                                    :bigint           not null, primary key
#  date                                  :datetime         not null
#  description                           :string
#  month                                 :integer          not null
#  price                                 :integer          not null
#  year                                  :integer          not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  cash_transaction_id                   :bigint           indexed
#  context_id                            :bigint           not null, indexed
#  investment_type_id                    :bigint           not null, indexed
#  piggy_bank_return_cash_transaction_id :bigint           indexed
#  user_bank_account_id                  :bigint           not null, indexed
#  user_id                               :bigint           not null, indexed
#
# Indexes
#
#  index_investments_on_cash_transaction_id   (cash_transaction_id)
#  index_investments_on_context_id            (context_id)
#  index_investments_on_investment_type_id    (investment_type_id)
#  index_investments_on_piggy_bank_return_id  (piggy_bank_return_cash_transaction_id)
#  index_investments_on_user_bank_account_id  (user_bank_account_id)
#  index_investments_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (piggy_bank_return_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_id => users.id)
#
