# frozen_string_literal: true

class CashInstallment < Installment
  # @extends ..................................................................
  delegate :user, :user_id, :user_card, :user_card_id, to: :cash_transaction, allow_nil: true

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :skip_shared_paid_state_sync

  # @relationships ............................................................
  belongs_to :cash_transaction, counter_cache: true

  # @validations ..............................................................
  validates :cash_installments_count, presence: true
  validate :ensure_shared_paid_state_can_sync, if: :will_sync_shared_paid_state?

  # @callbacks ................................................................
  before_validation :set_installment_type, :set_paid, on: :create
  after_save :check_paid_situation
  after_commit :enqueue_shared_paid_state_sync!, on: :update, if: :did_sync_shared_paid_state?

  # @scopes ...................................................................
  default_scope { where(installment_type: :CashInstallment) }

  scope :due_today, -> { where(paid: false, date: [ Time.zone.today.beginning_of_day..Time.zone.today.end_of_day ]) }
  scope :by_categories, ->(categories) { joins(cash_transaction: :categories).where(cash_transaction: { categories: }) }
  scope :by_entities, ->(entities) { joins(cash_transaction: :entities).where(cash_transaction: { entities: }) }
  scope :by_categories_and_entities, ->(categories, entities) { joins(cash_transaction: %i[categories entities]).where(cash_transaction: { categories:, entities: }) }
  scope :by_categories_or_entities, lambda { |categories, entities|
    joins(cash_transaction: %i[categories entities]).where(cash_transaction: { categories: }).or(
      joins(cash_transaction: %i[categories entities]).where(cash_transaction: { entities: })
    ).distinct
  }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def transactable
    cash_transaction
  end

  # @protected_instance_methods ...............................................

  protected

  def imported?
    cash_transaction.imported
  end

  # @private_instance_methods .................................................

  private

  def set_installment_type
    self.installment_type = :CashInstallment
  end

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return if [ false, true ].include?(paid)

    self.paid = date.present? && Time.zone.today >= date
  end

  # Sets `cash_transaction.paid` as true if all its installments were paid.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def check_paid_situation
    cash_transaction.update_columns(paid: should_be_paid?)
    sync_mirrored_exchange_settlement! if cash_transaction.exchange_return?
    cash_transaction.sync_exchange_entity_transaction_statuses! if cash_transaction.exchange_return?

    return unless cash_transaction.card_payment?

    cash_transaction.card_installments.update(paid: should_be_paid?)
  end

  def should_be_paid?
    cash_transaction.cash_installments.where(paid: false).empty?
  end

  def sync_mirrored_exchange_settlement!
    return if cash_transaction.exchanges.card_bound.exists?

    exchange = cash_transaction.exchanges.find_by(number:)
    return if exchange.blank?

    attributes = {
      date:,
      month:,
      year:
    }

    return if attributes.all? { |key, value| exchange.public_send(key) == value }

    exchange.update_columns(attributes)
  end

  def shared_paid_state_transaction?
    cash_transaction.respond_to?(:shared_return_flow?) && cash_transaction.shared_return_flow?
  end

  def will_sync_shared_paid_state?
    return false if skip_shared_paid_state_sync
    return false unless persisted?
    return false if skip_shared_paid_state_sync_for_structural_correction?

    will_save_change_to_paid? && shared_paid_state_transaction?
  end

  def did_sync_shared_paid_state?
    return false if skip_shared_paid_state_sync
    return false if skip_shared_paid_state_sync_for_structural_correction?

    saved_change_to_paid? && shared_paid_state_transaction?
  end

  def ensure_shared_paid_state_can_sync
    return if shared_paid_state_sync_service.syncable?

    errors.add(:base, :counterpart_paid_state_sync_missing)
  end

  def enqueue_shared_paid_state_sync!
    SyncSharedPaidStateJob.perform_later(cash_installment_id: id, force_notify: true)
  end

  def shared_paid_state_sync_service
    @shared_paid_state_sync_service ||= Logic::SharedPaidStateSyncService.new(installment: self)
  end

  def skip_shared_paid_state_sync_for_structural_correction?
    cash_transaction.respond_to?(:editable_shared_return_structure_change_after_payment?, true) &&
      cash_transaction.send(:editable_shared_return_structure_change_after_payment?)
  end
end

# == Schema Information
#
# Table name: installments
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  balance                 :integer
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :datetime         not null, indexed => [date_year, date_month]
#  date_month              :integer          not null, indexed => [date_year, date]
#  date_year               :integer          not null, indexed => [date_month, date]
#  installment_type        :string           not null, indexed => [card_transaction_id], indexed => [cash_transaction_id]
#  month                   :integer          not null
#  number                  :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null, indexed
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_transaction_id     :bigint           indexed => [installment_type], indexed
#  cash_transaction_id     :bigint           indexed => [installment_type], indexed
#  order_id                :integer          indexed
#
# Indexes
#
#  idx_installments_order_id                  (order_id)
#  idx_installments_price                     (price)
#  idx_installments_type_card_transaction     (installment_type,card_transaction_id)
#  idx_installments_type_cash_transaction     (installment_type,cash_transaction_id)
#  idx_installments_year_month_date           (date_year,date_month,date)
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
