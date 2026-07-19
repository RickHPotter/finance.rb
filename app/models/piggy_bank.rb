# frozen_string_literal: true

class PiggyBank < ApplicationRecord
  # @extends ..................................................................
  module ProjectionAuditSource
    def sync_return_projection!(...)
      Audit::Operation.with_mutation_source(:piggy_bank_sync) { super }
    end

    private

    def create_return_projection!(...)
      Audit::Operation.with_mutation_source(:piggy_bank_sync) { super }
    end

    def destroy_return_projection!(...)
      Audit::Operation.with_mutation_source(:piggy_bank_sync) { super }
    end

    def sync_remaining_return_projection!(...)
      Audit::Operation.with_mutation_source(:piggy_bank_sync) { super }
    end
  end

  prepend ProjectionAuditSource

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :source_cash_transaction, class_name: "CashTransaction", inverse_of: :piggy_bank
  belongs_to :return_cash_transaction, class_name: "CashTransaction", inverse_of: :piggy_bank_return_links, optional: true

  # @validations ..............................................................
  validates :source_cash_transaction_id, uniqueness: true
  validates :return_date, presence: true
  validates :return_price, numericality: { greater_than: 0 }
  validate :validate_link_consistency
  validate :validate_return_group_eligibility, if: :return_cash_transaction
  validate :prevent_paid_history_projection_change, on: :update

  # @callbacks ................................................................
  before_validation :inherit_return_group_date, if: :return_cash_transaction
  after_create :create_return_projection!, unless: :return_cash_transaction_id?
  after_create :sync_return_projection!, if: :return_cash_transaction_id?
  after_update :sync_return_projection!, if: :saved_change_to_projection?
  before_destroy :destroy_return_projection!
  after_destroy :sync_remaining_return_projection!

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def paid_history?
    return_cash_transaction&.cash_installments&.any?(&:paid?) || false
  end

  def return_group_open?
    return_cash_transaction&.piggy_bank_group_open? || false
  end

  def sync_return_projection!
    return if return_cash_transaction.blank?

    return_transaction = return_cash_transaction
    return_transaction.with_lock do
      links = return_transaction.piggy_bank_return_links.reload
      grouped_price, remaining_price = grouped_projection_prices(return_transaction, links:)
      assign_grouped_return_attributes(return_transaction, links:, grouped_price:, remaining_price:)
      sync_return_allocations(return_transaction)
      sync_grouped_installments(return_transaction, remaining_price:)
      return_transaction.save!
    end
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def create_return_projection!
    return_transaction = CashTransaction.new(return_projection_attributes.merge(cash_transaction_type: "PiggyBank", reference_transactable: source_cash_transaction))
    return_transaction.piggy_bank_projection_write = true
    sync_return_allocations(return_transaction)
    sync_initial_installment(return_transaction)
    return_transaction.save!
    update_column(:return_cash_transaction_id, return_transaction.id)
    self.return_cash_transaction = return_transaction
    sync_return_projection!
  end

  def return_projection_attributes
    source_cash_transaction.slice(:description, :user_id, :context_id, :user_bank_account_id).merge(
      date: return_date,
      month: return_date.month,
      year: return_date.year,
      price: return_price,
      starting_price: return_price,
      paid: false
    )
  end

  def sync_return_allocations(return_transaction)
    return_category = source_cash_transaction.user.built_in_category("PIGGY BANK RETURN")
    return_transaction.category_transactions = [ CategoryTransaction.new(category: return_category) ] unless return_transaction.persisted?

    source_entity = source_cash_transaction.entity_transactions.reject(&:marked_for_destruction?).first&.entity
    return if source_entity.blank?

    if return_transaction.persisted?
      existing = return_transaction.entity_transactions.first
      if existing
        existing.assign_attributes(entity: source_entity, price: 0, price_to_be_returned: 0)
      else
        return_transaction.entity_transactions.build(entity: source_entity, price: 0, price_to_be_returned: 0, is_payer: false)
      end
    else
      return_transaction.entity_transactions.build(entity: source_entity, price: 0, price_to_be_returned: 0, is_payer: false)
    end
  end

  def sync_initial_installment(return_transaction)
    installment =
      if return_transaction.new_record?
        return_transaction.cash_installments.first
      else
        return_transaction.cash_installments.order(:number).first
      end
    installment ||= return_transaction.cash_installments.build(number: 1)
    installment.assign_attributes(initial_installment_attributes)
    installment
  end

  def initial_installment_attributes
    {
      number: 1,
      date: return_date,
      month: return_date.month,
      year: return_date.year,
      price: return_price,
      starting_price: return_price,
      paid: false
    }
  end

  def saved_change_to_projection?
    saved_change_to_return_price? || (saved_change_to_return_date? && return_cash_transaction&.piggy_bank_return_links&.one?)
  end

  def destroy_return_projection!
    return if return_cash_transaction.blank?

    if return_cash_transaction.piggy_bank_return_links.where.not(id:).exists?
      @shared_return_to_sync = return_cash_transaction
      return
    end

    if paid_history?
      errors.add(:base, :paid_history_locked)
      throw(:abort)
    end

    generated_return = return_cash_transaction
    update_column(:return_cash_transaction_id, nil)
    @destroyed_return_projection = true
    generated_return.piggy_bank_projection_write = true
    generated_return.destroy!
  end

  def sync_remaining_return_projection!
    return if @destroyed_return_projection || @shared_return_to_sync.blank?

    @shared_return_to_sync.piggy_bank_return_links.first&.sync_return_projection!
  end

  def validate_link_consistency
    return if source_cash_transaction.blank?
    return if return_cash_transaction.blank?

    errors.add(:return_cash_transaction, :invalid) unless return_cash_transaction.user_id == source_cash_transaction.user_id
    errors.add(:return_cash_transaction, :invalid) unless return_cash_transaction.context_id == source_cash_transaction.context_id
    errors.add(:return_cash_transaction, :invalid) unless return_cash_transaction.piggy_bank_return?
  end

  def validate_return_group_eligibility
    return if return_cash_transaction.blank? || source_cash_transaction.blank?

    errors.add(:return_cash_transaction, :closed) unless return_group_open? || return_cash_transaction.piggy_bank_return_links.empty?
    errors.add(:return_cash_transaction, :entity_mismatch) unless return_group_entity_id == source_entity_id

    errors.add(:return_price, :insufficient_for_paid_history) if grouped_price_with_current_link < paid_return_price
  end

  def grouped_price_with_current_link
    linked_principal = return_cash_transaction.piggy_bank_return_links.where.not(id:).sum(:return_price)
    valuation_delta = return_cash_transaction.piggy_bank_investments.sum(:price)
    linked_principal + valuation_delta + return_price.to_i
  end

  def paid_return_price
    return_cash_transaction.cash_installments.where(paid: true).sum(:price)
  end

  def inherit_return_group_date
    return unless new_record? || return_cash_transaction.piggy_bank_return_links.where.not(id:).exists?

    self.return_date = return_cash_transaction.date
  end

  def source_entity_id
    source_cash_transaction.entity_transactions.reject(&:marked_for_destruction?).first&.entity_id
  end

  def return_group_entity_id
    return_cash_transaction.entity_transactions.first&.entity_id
  end

  def sync_grouped_installments(return_transaction, remaining_price:)
    unpaid_installments = return_transaction.cash_installments.where(paid: false).order(:number).to_a

    if remaining_price.zero?
      unpaid_installments.each(&:destroy!)
      return
    end

    installment = unpaid_installments.shift || return_transaction.cash_installments.build(number: return_transaction.cash_installments.maximum(:number).to_i + 1)
    installment.assign_attributes(grouped_installment_attributes(return_transaction, remaining_price:))
    installment.save! if return_transaction.persisted?
    unpaid_installments.each(&:destroy!)
  end

  def grouped_projection_prices(return_transaction, links:)
    grouped_price = links.sum(:return_price) + return_transaction.piggy_bank_investments.sum(:price)
    remaining_price = grouped_price - return_transaction.cash_installments.where(paid: true).sum(:price)
    return [ grouped_price, remaining_price ] if grouped_price.positive? && !remaining_price.negative?

    errors.add(:return_price, :insufficient_for_paid_history)
    raise ActiveRecord::RecordInvalid, self
  end

  def assign_grouped_return_attributes(return_transaction, links:, grouped_price:, remaining_price:)
    return_transaction.piggy_bank_projection_write = true
    return_transaction.assign_attributes(
      date: links.one? ? links.first.return_date : return_transaction.date,
      month: links.one? ? links.first.return_date.month : return_transaction.month,
      year: links.one? ? links.first.return_date.year : return_transaction.year,
      price: grouped_price,
      starting_price: grouped_price,
      paid: remaining_price.zero?
    )
  end

  def grouped_installment_attributes(return_transaction, remaining_price:)
    {
      date: return_transaction.date,
      month: return_transaction.date.month,
      year: return_transaction.date.year,
      price: remaining_price,
      starting_price: remaining_price,
      paid: false
    }
  end

  def prevent_paid_history_projection_change
    return unless paid_history?
    return unless will_save_change_to_return_date? || will_save_change_to_return_price?

    errors.add(:base, :paid_history_locked)
  end
end

# == Schema Information
#
# Table name: piggy_banks
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  return_date                :datetime         not null
#  return_price               :integer          not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  return_cash_transaction_id :bigint           indexed
#  source_cash_transaction_id :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_piggy_banks_on_return_cash_transaction_id  (return_cash_transaction_id)
#  index_piggy_banks_on_source_cash_transaction_id  (source_cash_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (return_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (source_cash_transaction_id => cash_transactions.id)
#
