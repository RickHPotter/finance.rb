# frozen_string_literal: true

class CashTransaction < ApplicationRecord # rubocop:disable Metrics/ClassLength
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include FinancialAuditable
  include HasCashInstallments
  include HasFinancialSafetyRules
  include HasFinancialSafetyGuards
  include CategoryTransactable
  include EntityTransactable
  include HasSubscription
  include Budgetable
  include FriendNotifiable
  include PiggyBankCategorizable

  audits_financial_changes skip: %i[cash_installments_count]

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :min_date, :duplicate, :edit_phase, :skip_recalculate_balance, :source_message_id, :historical_correction_confirmation,
                :piggy_bank_projection_write

  FRIEND_NOTIFICATION_INTENTS = %w[loan reimbursement].freeze

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
  has_one :piggy_bank, foreign_key: :source_cash_transaction_id, dependent: :destroy, inverse_of: :source_cash_transaction
  has_many :piggy_bank_return_links, class_name: "PiggyBank", foreign_key: :return_cash_transaction_id, inverse_of: :return_cash_transaction
  has_many :piggy_bank_investments,
           class_name: "Investment",
           foreign_key: :piggy_bank_return_cash_transaction_id,
           inverse_of: :piggy_bank_return_cash_transaction,
           dependent: :restrict_with_error
  accepts_nested_attributes_for :piggy_bank, allow_destroy: true

  # @validations ..............................................................
  validates :context, presence: true
  validates :description, :cash_installments_count, presence: true
  validates :friend_notification_intent, inclusion: { in: FRIEND_NOTIFICATION_INTENTS }, allow_nil: true
  validate :friend_notification_intent_matches_exchange_category
  validate :friend_notification_intent_present_for_exchange_category
  validate :validate_piggy_bank_source_contract
  validate :prevent_paid_piggy_bank_rewrite, on: :update

  # @callbacks ................................................................
  before_validation :assign_default_context
  before_validation :remove_piggy_bank_without_source_category
  before_validation :derive_piggy_bank_entity_allocation
  before_validation :set_paid, on: :create
  before_destroy :prevent_linked_borrow_return_destruction, prepend: true
  before_destroy :prevent_piggy_bank_destruction, prepend: true
  after_initialize :build_default_cash_installments
  after_save :sync_subscription_installment, :sync_piggy_bank_projection, :set_min_date
  after_commit :update_cash_balance, :update_associations_total

  # @scopes ...................................................................
  scope :investment, -> { where(cash_transaction_type: "Investment") }
  scope :card_payment, -> { where(cash_transaction_type: "CardInstallment") }
  scope :card_advance, -> { where(cash_transaction_type: "CardTransaction") }
  scope :exchange_return, -> { where(cash_transaction_type: "Exchange") }
  scope :piggy_bank_return, -> { where(cash_transaction_type: "PiggyBank") }

  # @public_instance_methods ..................................................

  def self.open_piggy_bank_returns_for(user:, context:, entity_id: nil)
    scope = piggy_bank_return
            .joins(:entities, :piggy_bank_return_links)
            .where(user:, context:)
            .includes(:cash_installments, piggy_bank_return_links: { source_cash_transaction: :cash_installments })
            .distinct
    scope = scope.where(entities: { id: entity_id }) if entity_id.present?
    scope.select(&:piggy_bank_group_open?)
  end

  def self.duplicate(id)
    existing_cash_transaction = includes(:piggy_bank, :cash_installments, :category_transactions, entity_transactions: %i[entity exchanges]).find(id)

    cash_transaction = existing_cash_transaction.dup
    cash_transaction.duplicate = true
    cash_transaction.cash_installments = duplicated_cash_installments_for(existing_cash_transaction)
    cash_transaction.category_transactions = existing_cash_transaction.category_transactions.map(&:dup)
    cash_transaction.entity_transactions = duplicated_entity_transactions_for(existing_cash_transaction)
    cash_transaction.build_piggy_bank(existing_cash_transaction.piggy_bank.slice(:return_date, :return_price)) if existing_cash_transaction.piggy_bank.present?

    cash_transaction
  end

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
    return false if generated_piggy_bank_return?

    !categories.pluck(:category_name).intersect?([ "CARD PAYMENT", "INVESTMENT" ])
  end

  def can_be_deleted?
    return false if linked_borrow_return?
    return false if generated_piggy_bank_return?

    !categories.pluck(:category_name).intersect?([ "CARD PAYMENT", "CARD INSTALLMENT", "INVESTMENT", "EXCHANGE RETURN" ])
  end

  def bulk_transfer_eligible?
    !generated_piggy_bank_return? && !categories.pluck(:category_name).intersect?([ "CARD PAYMENT", "CARD ADVANCE", "INVESTMENT" ])
  end

  def bulk_subscription_eligible?
    !generated_piggy_bank_return? && !categories.pluck(:category_name).intersect?([ "CARD PAYMENT", "CARD ADVANCE", "INVESTMENT" ])
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

  def generated_piggy_bank_return?
    piggy_bank_return? && (piggy_bank_return_links.present? || cash_transaction_type == "PiggyBank")
  end

  def piggy_bank_group_open?
    return false unless generated_piggy_bank_return?

    source_ids = piggy_bank_return_links.map(&:source_cash_transaction_id)
    sources_paid = !CashInstallment.where(cash_transaction_id: source_ids, paid: false).exists?
    return_paid = !cash_installments.where(paid: false).exists?

    !sources_paid || !return_paid
  end

  def borrow_return?
    return true if persisted? && categories.pluck(:category_name).include?("BORROW RETURN")
    return true if destroyed? && original_categories.include?(user.categories.where(category_name: "BORROW RETURN").first.id)

    reference_transactable.present? && reference_transactable.user_id != user.id
  end

  def shared_return_flow?
    return false unless exchange_return? || borrow_return?

    return true if reference_transactable.is_a?(CashTransaction) && reference_transactable.user_id != user.id

    counterpart_shared_return_transaction.present?
  end

  def failed_return?
    persisted? && categories.pluck(:category_name).include?("FAILED LEND/BORROW RETURN")
  end

  def exchange_category?
    exchange_category = user&.categories&.find_by(category_name: "EXCHANGE")
    exchange_category_id = exchange_category&.id

    category_transactions.reject(&:marked_for_destruction?).any? do |category_transaction|
      category_transaction.category_id == exchange_category_id || category_transaction.category&.category_name == "EXCHANGE"
    end
  end

  def return_failure_reportable?
    (exchange_return? || borrow_return?) && cash_installments.where(paid: false).where.not(price: 0).exists?
  end

  def report_payment_failure!
    failed_category = user.built_in_category("FAILED LEND/BORROW RETURN")
    categories << failed_category unless categories.exists?(failed_category.id)
    cash_installments.where(paid: false).where.not(price: 0).find_each do |installment|
      installment.update!(starting_price: installment.price, price: 0)
    end
  end

  def clear_failed_return_if_recovered!
    return unless failed_return?
    return if cash_installments.where(paid: false, price: 0).exists?

    category_transactions.joins(:category).where(categories: { category_name: "FAILED LEND/BORROW RETURN" }).destroy_all
  end

  def counterpart_shared_return_transaction
    return @counterpart_shared_return_transaction if defined?(@counterpart_shared_return_transaction) && @counterpart_shared_return_transaction.present?

    @counterpart_shared_return_transaction = chain_counterpart_shared_return_transaction
  end

  def reference_root_transaction(visited = [])
    return self if reference_transactable.blank?

    visit_key = [ self.class.name, id ]
    return self if visited.include?(visit_key)

    visited << visit_key
    return reference_transactable unless reference_transactable.respond_to?(:reference_root_transaction)

    reference_transactable.reference_root_transaction(visited)
  end

  def reference_children(scope: CashTransaction.all)
    self.class.reference_children_for(self, scope:)
  end

  def first_reference_descendant(scope: CashTransaction.all)
    self.class.first_reference_descendant_for(self, scope:)
  end

  def self.reference_children_for(reference, scope: all)
    return [] if reference.blank?

    scope.where(reference_transactable: reference).order(:created_at, :id).to_a
  end

  def self.reference_descendants_for(reference, scope: all, visited: [])
    return [] if reference.blank?

    visit_key = [ reference.class.name, reference.id ]
    return [] if visited.include?(visit_key)

    visited << visit_key
    direct_children = reference_children_for(reference, scope:)

    direct_children + direct_children.flat_map do |child|
      reference_descendants_for(child, scope:, visited: visited.dup)
    end
  end

  def self.reference_family_for(reference, scope: all)
    return [] if reference.blank?

    [ reference, *reference_descendants_for(reference, scope:) ].uniq { |candidate| [ candidate.class.name, candidate.id ] }
  end

  def self.first_reference_descendant_for(reference, scope: all)
    return if reference.blank?

    direct_children = reference_children_for(reference)
    matching_child_ids = scope.where(id: direct_children.map(&:id)).pluck(:id)
    matching_child = direct_children.find { |child| matching_child_ids.include?(child.id) }
    return matching_child if matching_child.present?

    direct_children.each do |child|
      descendant = first_reference_descendant_for(child, scope:)
      return descendant if descendant.present?
    end

    nil
  end

  def counterpart_shared_return_user
    entity_transactions.joins(:entity)
                       .where.not(entities: { entity_user_id: nil })
                       .where.not(entities: { entity_user_id: user_id })
                       .pick("entities.entity_user_id")
                       .then { |counterpart_user_id| User.find_by(id: counterpart_user_id) }
  end

  def can_be_destroyed?
    return false if card_payment? || card_advance? || exchange_return? || investment? || linked_borrow_return? || generated_piggy_bank_return?

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

      Audit::BulkMutation.update_columns!(
        entity_transaction,
        status: all_non_monetary_and_paid ? EntityTransaction.statuses[:finished] : EntityTransaction.statuses[:pending]
      )
    end
  end

  def sync_exchange_projection_back_to_source! # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/PerceivedComplexity
    return unless exchange_return?

    payer_entity_transactions = exchanges.includes(:entity_transaction)
                                         .map(&:entity_transaction)
                                         .compact
                                         .select(&:is_payer?)
                                         .uniq
    return unless payer_entity_transactions.one?

    payer_entity_transaction = payer_entity_transactions.first
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

    desired_rows.each do |row| # rubocop:disable Metrics/BlockLength
      exchange = existing_by_number.delete(row[:number])

      if exchange.present?
        Audit::BulkMutation.update_columns!(exchange, row.merge(exchanges_count:, updated_at: now))
      else
        Audit::BulkMutation.insert!(
          Exchange,
          {
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
          }
        )
      end
    end

    Audit::BulkMutation.delete_all!(Exchange.where(id: existing_by_number.values.map(&:id))) if existing_by_number.present?

    Audit::BulkMutation.update_columns!(payer_entity_transaction, price: total_price, price_to_be_returned: total_price, exchanges_count:)
    Audit::BulkMutation.update_all!(payer_entity_transaction.exchanges, exchanges_count:) if exchanges_count.positive?
  end

  def effective_friend_notification_intent
    return friend_notification_intent if friend_notification_intent.present?

    latest_friend_notification_intent
  end

  def active_notification_messages
    notification_messages_scope
      .where(body: %w[notification:create notification:update])
      .where(superseded_by_id: nil)
      .where.not(headers: [ nil, "" ])
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def validate_piggy_bank_source_contract
    return unless piggy_bank_source?

    errors.add(:price, :piggy_bank_source_negative) unless price.to_i.negative?
    errors.add(:base, :piggy_bank_requires_one_entity) unless active_piggy_bank_entity_transactions.one?
    errors.add(:piggy_bank, :blank) if piggy_bank.blank? || piggy_bank.marked_for_destruction?
  end

  def remove_piggy_bank_without_source_category
    piggy_bank&.mark_for_destruction if piggy_bank.present? && !piggy_bank_source?
  end

  def derive_piggy_bank_entity_allocation
    return unless piggy_bank_source?

    active_piggy_bank_entity_transactions.each do |entity_transaction|
      entity_transaction.assign_attributes(price: price.to_i.abs, price_to_be_returned: 0, is_payer: false)
    end
  end

  def active_piggy_bank_entity_transactions
    entity_transactions.reject(&:marked_for_destruction?).select { |entity_transaction| entity_transaction.entity_id.present? || entity_transaction.entity.present? }
  end

  def prevent_paid_piggy_bank_rewrite
    return if piggy_bank.blank? || !piggy_bank.paid_history?

    projection_changed = piggy_bank.changed? || piggy_bank.marked_for_destruction?
    source_changed = will_save_change_to_price? || will_save_change_to_user_bank_account_id? || piggy_bank_allocation_changed?
    errors.add(:base, :piggy_bank_paid_history_locked) if projection_changed || source_changed
  end

  def piggy_bank_allocation_changed?
    original_category_ids = Array(original_categories).map(&:to_i).sort
    original_entity_ids = Array(original_entities).map(&:to_i).sort
    current_category_ids = category_transactions.reject(&:marked_for_destruction?).map(&:category_id).compact.sort
    category_changed = original_category_ids.present? && original_category_ids != current_category_ids
    entity_changed = original_entity_ids.present? && original_entity_ids != entity_transactions.reject(&:marked_for_destruction?).map(&:entity_id).compact.sort

    category_changed || entity_changed
  end

  def sync_piggy_bank_projection
    piggy_bank&.sync_return_projection! if piggy_bank&.persisted?
  end

  def prevent_piggy_bank_destruction
    if piggy_bank.present?
      return unless piggy_bank.paid_history?

      errors.add(:base, :piggy_bank_paid_history_locked)
      throw(:abort)
    end

    return if piggy_bank_return_links.blank? || piggy_bank_projection_write

    errors.add(:base, cash_installments.any?(&:paid?) ? :piggy_bank_paid_history_locked : :piggy_bank_return_system_managed)
    throw(:abort)
  end

  def self.duplicated_cash_installments_for(transaction)
    ordered_cash_installments_for_duplicate(transaction).map do |installment|
      installment.dup.tap do |duplicate_installment|
        duplicate_installment.paid = false
      end
    end
  end

  def self.duplicated_entity_transactions_for(transaction)
    ordered_entity_transactions_for_duplicate(transaction).map do |entity_transaction|
      entity_transaction.dup.tap do |duplicate_entity_transaction|
        duplicate_entity_transaction.exchanges = duplicated_exchanges_for(entity_transaction)
        duplicate_entity_transaction.exchanges_count = duplicate_entity_transaction.exchanges.size
      end
    end
  end

  def self.duplicated_exchanges_for(entity_transaction)
    ordered_exchanges_for_duplicate(entity_transaction).each_with_index.map do |exchange, index|
      exchange.dup.tap do |duplicate_exchange|
        duplicate_exchange.number = index + 1
      end
    end
  end

  def self.ordered_cash_installments_for_duplicate(transaction)
    transaction.cash_installments.sort_by do |installment|
      [ installment.number.to_i, installment.year.to_i, installment.month.to_i, installment.date || Time.zone.at(0), installment.id.to_i ]
    end
  end

  def self.ordered_entity_transactions_for_duplicate(transaction)
    transaction.entity_transactions.sort_by do |entity_transaction|
      [ entity_transaction.entity&.entity_name.to_s, entity_transaction.id.to_i ]
    end
  end

  def self.ordered_exchanges_for_duplicate(entity_transaction)
    entity_transaction.exchanges.sort_by do |exchange|
      [ exchange.number.to_i, exchange.year.to_i, exchange.month.to_i, exchange.date || Time.zone.at(0), exchange.id.to_i ]
    end
  end

  private_class_method :duplicated_cash_installments_for,
                       :duplicated_entity_transactions_for,
                       :duplicated_exchanges_for,
                       :ordered_cash_installments_for_duplicate,
                       :ordered_entity_transactions_for_duplicate,
                       :ordered_exchanges_for_duplicate

  def prevent_linked_borrow_return_destruction
    return if context_destroying?
    return unless linked_borrow_return?

    errors.add(:base, :destroy_linked_shared_return)
    throw(:abort)
  end

  def linked_borrow_return?
    borrow_return? && reference_transactable.present?
  end

  def friend_notification_intent_matches_exchange_category
    return unless !exchange_category? && friend_notification_intent.present?

    errors.add(:friend_notification_intent, :invalid)
  end

  def friend_notification_intent_present_for_exchange_category
    return unless exchange_category? && friend_notification_intent.blank?

    errors.add(:friend_notification_intent, :blank)
  end

  def context_destroying?
    context&.destroying_for_removal?
  end

  def assign_default_context
    self.context ||= user&.ensure_main_context!
  end

  def latest_friend_notification_intent
    return if new_record?

    headers = notification_messages_scope
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

  def notification_messages_scope
    family_references = notification_reference_family
    return Message.none if family_references.blank?

    reference_conditions = family_references.group_by { |reference| reference.class.name }.map do |type, references|
      Message.arel_table[:reference_transactable_type].eq(type)
             .and(Message.arel_table[:reference_transactable_id].in(references.map(&:id)))
    end

    Message.where(user:).where(reference_conditions.reduce(&:or))
  end

  def notification_reference_family
    family_root = reference_root_transaction.presence || self
    return [] unless family_root.is_a?(CashTransaction) || family_root.is_a?(CardTransaction)

    self.class.reference_family_for(family_root)
  end

  def chain_counterpart_shared_return_transaction
    cross_user_reference_shared_return_transaction || descendant_counterpart_shared_return_transaction
  end

  def cross_user_reference_shared_return_transaction
    current_reference = reference_transactable
    visited = []

    while current_reference.is_a?(CashTransaction)
      visit_key = [ current_reference.class.name, current_reference.id ]
      return if visited.include?(visit_key)

      visited << visit_key
      return current_reference if current_reference.user_id != user_id && current_reference.categories.pluck(:category_name).intersect?([ "EXCHANGE RETURN",
                                                                                                                                          "BORROW RETURN" ])

      current_reference = current_reference.reference_transactable
    end

    nil
  end

  def descendant_counterpart_shared_return_transaction
    counterpart_user = counterpart_shared_return_user
    return if counterpart_user.blank?

    counterpart_context = counterpart_shared_return_context(counterpart_user)
    return if counterpart_context.blank?

    shared_return_transaction_from_descendant(first_reference_descendant(scope: counterpart_context.cash_transactions),
                                              scope: counterpart_context.cash_transactions)
  end

  def shared_return_transaction_from_descendant(descendant, scope:)
    current_descendant = descendant

    while current_descendant.present?
      return current_descendant if shared_return_counterpart_candidate?(current_descendant)

      current_descendant = current_descendant.first_reference_descendant(scope:)
    end

    nil
  end

  def shared_return_counterpart_candidate?(transaction)
    transaction.categories.pluck(:category_name).intersect?([ "EXCHANGE RETURN", "BORROW RETURN" ]).present?
  end

  def counterpart_shared_return_context(counterpart_user)
    if context.main? || context.scenario_key.blank?
      counterpart_user.ensure_main_context!
    else
      counterpart_user.contexts.find_by(scenario_key: context.scenario_key)
    end
  end

  def build_default_cash_installments
    cash_installments.new(number: 1, price:, date:) if cash_installments.empty?
  end

  def sync_subscription_installment
    return if subscription_id.blank? || cash_installments_count != 1

    Audit::BulkMutation.update_columns!(cash_installments.first, price:, starting_price: price) if cash_installments.first
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
#  friend_notification_intent  :string
#  imported                    :boolean          default(FALSE)
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null
#  reference_transactable_type :string           indexed => [reference_transactable_id]
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  context_id                  :bigint           not null, indexed
#  investment_type_id          :bigint           indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_bank_account_id        :bigint           indexed
#  user_card_id                :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_context_id              (context_id)
#  index_cash_transactions_on_investment_type_id      (investment_type_id)
#  index_cash_transactions_on_reference_transactable  (reference_transactable_type,reference_transactable_id)
#  index_cash_transactions_on_subscription_id         (subscription_id)
#  index_cash_transactions_on_user_bank_account_id    (user_bank_account_id)
#  index_cash_transactions_on_user_card_id            (user_card_id)
#  index_cash_transactions_on_user_id                 (user_id)
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
