# frozen_string_literal: true

class CashTransaction < ApplicationRecord # rubocop:disable Metrics/ClassLength
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasCashInstallments
  include HasFinancialSafetyRules
  include HasFinancialSafetyGuards
  include CategoryTransactable
  include EntityTransactable
  include HasSubscription
  include Budgetable
  include FriendNotifiable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :min_date, :duplicate, :edit_phase, :skip_recalculate_balance, :friend_notification_intent, :source_message_id, :historical_correction_confirmation

  # @relationships ............................................................
  belongs_to :user
  belongs_to :context, optional: false
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, counter_cache: true, optional: true
  belongs_to :investment_type, optional: true
  belongs_to :reference_transactable, polymorphic: true, optional: true

  has_many :card_installments, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :exchanges

  # @validations ..............................................................
  validates :context, presence: true
  validates :description, :cash_installments_count, presence: true
  validate :prevent_direct_exchange_projection_structure_edit, on: :update

  # @callbacks ................................................................
  before_validation :assign_default_context
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

    reference_transactable.present? && reference_transactable.user_id != user.id
  end

  def shared_return_flow?
    return false unless exchange_return? || borrow_return?

    return true if reference_transactable.is_a?(CashTransaction) && reference_transactable.user_id != user.id
    return true if counterpart_shared_return_transaction.present?

    counterpart_shared_return_user.present? && shared_return_notification_history?
  end

  def counterpart_shared_return_transaction
    return @counterpart_shared_return_transaction if defined?(@counterpart_shared_return_transaction) && @counterpart_shared_return_transaction.present?

    @counterpart_shared_return_transaction =
      direct_counterpart_shared_return_transaction || structurally_matched_counterpart_shared_return_transaction
  end

  def counterpart_shared_return_user
    entity_transactions.joins(:entity)
                       .where.not(entities: { entity_user_id: nil })
                       .where.not(entities: { entity_user_id: user_id })
                       .pick("entities.entity_user_id")
                       .then { |counterpart_user_id| User.find_by(id: counterpart_user_id) }
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

  def sync_exchange_entity_transaction_statuses!
    exchanges.includes(:entity_transaction).map(&:entity_transaction).uniq.each do |entity_transaction|
      all_non_monetary_and_paid = entity_transaction.exchanges.includes(:cash_transaction).all? do |exchange|
        exchange.non_monetary? || exchange.mirrored_paid?
      end

      entity_transaction.update_columns(status: all_non_monetary_and_paid ? EntityTransaction.statuses[:finished] : EntityTransaction.statuses[:pending])
    end
  end

  def sync_exchange_projection_back_to_source! # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    return unless exchange_return?

    payer_entity_transaction = exchanges.includes(:entity_transaction).first&.entity_transaction
    return if payer_entity_transaction.blank?

    desired_rows = cash_installments.order(:number, :date).map do |installment|
      {
        number: installment.number,
        date: installment.date,
        month: installment.month,
        year: installment.year,
        price: installment.price,
        starting_price: installment.price
      }
    end

    existing_exchanges = payer_entity_transaction.exchanges.monetary.order(:number, :date).to_a
    existing_by_number = existing_exchanges.index_by(&:number)
    exchanges_count = desired_rows.count
    bound_type = existing_exchanges.first&.bound_type || (user_card_id.present? ? "card_bound" : "standalone")
    total_price = desired_rows.sum { |row| row[:price] }
    now = Time.current

    desired_rows.each do |row|
      exchange = existing_by_number.delete(row[:number])

      if exchange.present?
        exchange.update_columns(row.merge(exchanges_count:, updated_at: now))
      else
        Exchange.insert({
                          entity_transaction_id: payer_entity_transaction.id,
                          cash_transaction_id: id,
                          bound_type:,
                          exchange_type: Exchange.exchange_types.fetch(:monetary),
                          number: row[:number],
                          date: row[:date],
                          month: row[:month],
                          year: row[:year],
                          price: row[:price],
                          starting_price: row[:starting_price],
                          exchanges_count:,
                          created_at: now,
                          updated_at: now
                        })
      end
    end

    Exchange.where(id: existing_by_number.values.map(&:id)).delete_all if existing_by_number.present?

    payer_entity_transaction.update_columns(price: total_price, price_to_be_returned: total_price, exchanges_count:)
    payer_entity_transaction.exchanges.update_all(exchanges_count:) if exchanges_count.positive?
  end

  def effective_friend_notification_intent
    return friend_notification_intent if friend_notification_intent.present?

    latest_friend_notification_intent
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def prevent_direct_exchange_projection_structure_edit
    return unless exchange_return?
    return unless persisted?

    return if respond_to?(:shared_paid_state_toggle_only?, true) && shared_paid_state_toggle_only?
    return if editable_unpaid_exchange_projection_change?
    return unless direct_exchange_projection_structure_edit_attempted?

    errors.add(:base, :exchange_projection_locked)
  end

  def direct_exchange_projection_structure_edit_attempted?
    return true if will_save_change_to_price? || will_save_change_to_date? || will_save_change_to_month? || will_save_change_to_year?

    cash_installments.any? do |installment|
      installment.marked_for_destruction? ||
        installment.new_record? ||
        installment.changes.except("updated_at", "paid").present?
    end
  end

  def editable_unpaid_exchange_projection_change?
    touched_installments = cash_installments.select do |installment|
      installment.marked_for_destruction? ||
        installment.new_record? ||
        installment.changes.except("updated_at", "paid", "cash_installments_count").present?
    end

    touched_installments.present? && touched_installments.all? { |installment| installment.new_record? || !installment.paid? }
  end

  def assign_default_context
    self.context ||= user&.ensure_main_context!
  end

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

  def shared_return_notification_history?
    Message.where(reference_transactable: self, user:)
           .where(body: %w[notification:create notification:update notification:destroy notification:paid_state])
           .exists?
  end

  def direct_counterpart_shared_return_transaction
    CashTransaction.where(reference_transactable: self).where.not(user_id: user_id).first
  end

  def structurally_matched_counterpart_shared_return_transaction
    counterpart_user = counterpart_shared_return_user
    return if counterpart_user.blank?

    counterpart_context = if context.main? || context.scenario_key.blank?
                            counterpart_user.ensure_main_context!
                          else
                            counterpart_user.contexts.find_by(scenario_key: context.scenario_key)
                          end
    return if counterpart_context.blank?

    counterpart_context.cash_transactions
                       .includes(:categories, :cash_installments, entity_transactions: :entity)
                       .select do |transaction|
      next false if transaction.id == id
      next false unless transaction.exchange_return? || transaction.borrow_return?
      next false unless transaction.entity_transactions.joins(:entity).where(entities: { entity_user_id: user_id }).exists?

      transaction.send(:shared_return_structure_signature) == shared_return_structure_signature
    end
                     .first
  end

  def shared_return_structure_signature
    cash_installments.order(:number, :date).map do |installment|
      [ installment.number, installment.month, installment.year, installment.price.abs ]
    end
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

    Logic::RecalculateBalancesService.new(user:, context:, year: date.year, month: date.month).call and return if destroyed?

    self.min_date ||= cash_installments.order(:date).first.date.beginning_of_month
    Logic::RecalculateBalancesService.new(user:, context:, year: min_date.year, month: min_date.month).call
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
#  context_id                  :bigint           not null, indexed
#  investment_type_id          :bigint           indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type], uniquely indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_bank_account_id        :bigint           indexed
#  user_card_id                :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_context_id               (context_id)
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
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (subscription_id => finance_subscriptions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
