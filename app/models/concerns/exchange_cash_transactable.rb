# frozen_string_literal: true

# Shared functionality for models that can produce CashTransactions.
module ExchangeCashTransactable # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    enum :bound_type, { standalone: "standalone", card_bound: "card_bound" }
    attr_accessor :destroyed_projection_cash_transaction_id

    # @extends ................................................................
    delegate :transactable, to: :entity_transaction
    delegate :user, to: :transactable

    # @relationships ..........................................................
    belongs_to :cash_transaction, optional: true

    # @callbacks ..............................................................
    after_validation :update_entity_transaction_status, on: :update
    before_update :prevent_locked_projection_rewrite, prepend: true, if: -> { cash_transaction.present? }
    before_create :create_cash_transaction, if: :monetary?
    before_update :update_cash_transaction, if: :monetary?
    before_update :destroy_cash_transaction, if: :non_monetary?
    before_destroy :prevent_locked_projection_destruction, prepend: true, if: -> { cash_transaction.present? }
    before_destroy :remember_projection_cash_transaction_id, if: -> { cash_transaction.present? }
    before_destroy :update_or_destroy_cash_transaction, if: -> { cash_transaction.present? }
    after_destroy :cleanup_orphaned_projection_cash_transaction
  end

  # @class_methods ............................................................
  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def prevent_locked_projection_rewrite
    return unless cash_transaction&.paid_history?
    return unless projection_sync_relevant_change?
    return if editable_unpaid_projection_change?

    errors.add(:base, :paid_history_locked)
    throw(:abort)
  end

  def prevent_locked_projection_destruction
    return if transactable.respond_to?(:context_destroying?, true) && transactable.send(:context_destroying?)
    return unless cash_transaction&.paid_history?
    return if editable_unpaid_projection_destruction?
    return if transactable.respond_to?(:confirmed_destroy_with_history?, true) &&
              transactable.send(:confirmed_destroy_with_history?)

    errors.add(:base, :destroy_locked_after_payment)
    throw(:abort)
  end

  # Sets the `status` of the `entity_transaction` based on the existing `exchanges`.
  # In case there is only `non_monetary?` `exchanges`, then `status` is set to `finished`.
  # In case there are `monetary?` and they are all `paid`, then `status` is also set to `finished`.
  # Otherwise, `status` is set to `pending`.
  #
  # @note This is a method that is called after_validation.
  #
  # @return [void].
  #
  def update_entity_transaction_status
    return if entity_transaction.exchanges.empty?

    all_non_monetary_and_paid = [ *entity_transaction.exchanges, self ].all? do |exchange|
      exchange.non_monetary? || exchange.cash_transaction.try(:paid)
    end

    entity_transaction.status = all_non_monetary_and_paid ? :finished : :pending
  end

  # Creates a new `cash_transaction` if `exchange_type` is `monetary`.
  #
  # @note This is a method that is called before_create.
  #
  # @see {CashTransaction}.
  # @see {#cash_transaction_params}.
  #
  # @return [void].
  #
  def create_cash_transaction
    manually_assigned_projection_cash_transaction = cash_transaction.present? && cash_transaction.persisted?
    existing_projection_cash_transaction = shared_projection_cash_transaction
    created_projection_cash_transaction = existing_projection_cash_transaction.blank?
    initial_projection_sync = !manually_assigned_projection_cash_transaction &&
                              (created_projection_cash_transaction ||
                               (transactable.previously_new_record? && projection_cash_transaction_without_paid_history?(existing_projection_cash_transaction)))

    self.cash_transaction = existing_projection_cash_transaction || CashTransaction.create(projection_cash_transaction_params)
    assign_projection_cash_transaction_to_siblings!
    sync_projection_cash_transaction!(
      cash_transaction:,
      exchanges: synchronized_projection_exchanges(cash_transaction:),
      allow_initial_paid_projection_rebuild: initial_projection_sync
    )
  end

  # @note This is a method that is called before_update.
  #
  # @see {#create_cash_transaction}.
  # @see {#cash_transaction_params}.
  #
  # @return [void].
  #
  def update_cash_transaction
    create_cash_transaction and return if cash_transaction.nil?

    return unless projection_sync_relevant_change?

    rehome_card_bound_exchange_before_sync! if card_bound_projection_bucket_changed?

    assign_projection_cash_transaction_to_siblings!
    sync_projection_cash_transaction!(cash_transaction:, exchanges: synchronized_projection_exchanges(cash_transaction:))
  end

  # Sets `cash_transaction_id` to nil if `exchange_type` has changed to `non_monetary`.
  # It then proceeds to destroy the associated `cash_transaction`.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void].
  #
  def destroy_cash_transaction
    return if cash_transaction.nil?

    remaining_exchanges = synchronized_projection_exchanges(cash_transaction:, excluding: self)

    if remaining_exchanges.empty?
      _destroy_cash_transaction
    else
      sync_projection_cash_transaction!(cash_transaction:, exchanges: remaining_exchanges, removed_exchange: self)
    end
  end

  # Sets `cash_transaction_id` to nil if the `EXCHANGE RETURN` category has been removed.
  # It then proceeds to destroy the associated `cash_transaction`.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void].
  #
  def update_or_destroy_cash_transaction
    sibling_exchanges = synchronized_projection_exchanges(cash_transaction:, excluding: self)

    if sibling_exchanges.empty?
      _destroy_cash_transaction
    else
      sync_projection_cash_transaction!(cash_transaction:, exchanges: sibling_exchanges, removed_exchange: self)
    end
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `cash_transaction`.
  #
  def cash_transaction_params
    transactable
      .slice(:user_card_id)
      .merge(description: projection_description,
             starting_price:,
             price:,
             date:,
             year:,
             month:,
             user_id: user.id,
             context_id: transactable.context_id,
             cash_transaction_type: model_name.name,
             skip_recalculate_balance: true,
             category_transactions_attributes:,
             entity_transactions_attributes:)
  end

  def category_transactions_attributes
    [ { category_id: user.built_in_category("EXCHANGE RETURN").id } ]
  end

  def entity_transactions_attributes
    [ { id: nil, is_payer: false, price: 0, entity_id: entity_transaction.entity.id } ]
  end

  def card_bound_cash_transaction_params
    cash_transaction_params.merge(description: projection_description)
  end

  def cash_transaction_conditions
    params = cash_transaction_params
    params[:categories] = { id: params.delete(:category_transactions_attributes).pluck(:category_id) }
    params[:entities] = { id: params.delete(:entity_transactions_attributes).pluck(:entity_id) }

    params.delete(:categories) if params[:categories][:id].empty?
    params.delete(:entities) if params[:entities][:id].empty?

    params.without(:starting_price, :price, :date)
  end

  def card_bound_cash_transaction_conditions
    cash_transaction_conditions.merge(description: projection_description)
  end

  def _destroy_cash_transaction
    previous_cash_transaction = cash_transaction

    if persisted?
      update_columns(cash_transaction_id: nil)
    else
      self.cash_transaction = nil
    end

    Exchange.where(cash_transaction_id: previous_cash_transaction.id).update_all(cash_transaction_id: nil) if previous_cash_transaction&.persisted?
    delete_projection_cash_transaction(previous_cash_transaction)
  end

  def remember_projection_cash_transaction_id
    self.destroyed_projection_cash_transaction_id = cash_transaction_id
  end

  def cleanup_orphaned_projection_cash_transaction
    return if destroyed_projection_cash_transaction_id.blank?
    return if Exchange.where(cash_transaction_id: destroyed_projection_cash_transaction_id).exists?

    delete_projection_cash_transaction(CashTransaction.find_by(id: destroyed_projection_cash_transaction_id))
  end

  def sync_projection_cash_transaction!(cash_transaction:, exchanges: projection_exchanges, allow_initial_paid_projection_rebuild: false, removed_exchange: nil)
    return _destroy_cash_transaction if exchanges.empty?

    projection_price = projection_cash_transaction_price(cash_transaction:, exchanges:, removed_exchange:)
    return _destroy_cash_transaction if projection_price.zero?

    projection_date = projection_cash_transaction_date(exchanges)
    projection_month, projection_year = if card_bound?
                                          card_bound_projection_bucket_month_year(exchanges)
                                        else
                                          [ projection_date.month, projection_date.year ]
                                        end

    cash_transaction.update_columns(
      description: projection_description,
      starting_price: projection_price,
      price: projection_price,
      date: projection_date,
      month: projection_month,
      year: projection_year
    )

    rebuild_projection_installments!(
      cash_transaction:,
      exchanges:,
      allow_initial_paid_projection_rebuild:,
      projection_date:
    )
    cash_transaction.update_columns(
      cash_installments_count: cash_transaction.cash_installments.count,
      paid: cash_transaction.cash_installments.where(paid: false).none?
    )
    sync_projection_reference_transactable!(cash_transaction:)
  end

  def rebuild_projection_installments!(cash_transaction:, exchanges:, allow_initial_paid_projection_rebuild: false, projection_date: nil)
    if allow_initial_paid_projection_rebuild
      cash_transaction.cash_installments.delete_all
      return rebuild_card_bound_projection_installment!(cash_transaction:, exchanges:, projection_date:) if card_bound?

      return rebuild_unlocked_projection_installments!(cash_transaction:, exchanges:)
    end

    if projection_exchange_paid_state_available?(exchanges)
      cash_transaction.cash_installments.delete_all
      return rebuild_card_bound_projection_installment!(cash_transaction:, exchanges:, projection_date:) if card_bound?

      return rebuild_unlocked_projection_installments!(cash_transaction:, exchanges:, paid_by_exchange: true)
    end

    if cash_transaction.cash_installments.where(paid: true).exists?
      return rebuild_standalone_projection_installments_preserving_paid!(cash_transaction:, exchanges:) if standalone? && editable_unpaid_projection_change?
      return rebuild_card_bound_projection_installments_preserving_paid!(cash_transaction:, exchanges:, projection_date:) if card_bound?

      raise "Cannot rebuild paid projection installments"
    end

    cash_transaction.cash_installments.delete_all
    return rebuild_card_bound_projection_installment!(cash_transaction:, exchanges:, projection_date:) if card_bound?

    rebuild_unlocked_projection_installments!(cash_transaction:, exchanges:)
  end

  def rebuild_unlocked_projection_installments!(cash_transaction:, exchanges:, paid_by_date: false, paid_by_exchange: false)
    installments_count = exchanges.count
    exchanges.sort_by do |exchange|
      [ exchange.date, exchange.number, exchange.persisted? ? 0 : 1, exchange.id || Float::INFINITY ]
    end.each_with_index do |exchange, index| # rubocop:disable Style/MultilineBlockChain
      cash_transaction.cash_installments.create!(
        number: index + 1,
        date: exchange.date,
        month: exchange.month,
        year: exchange.year,
        price: exchange.price,
        starting_price: exchange.price,
        cash_installments_count: installments_count,
        paid: projected_exchange_paid_state(exchange, paid_by_date:, paid_by_exchange:)
      )
    end
  end

  def rebuild_standalone_projection_installments_preserving_paid!(cash_transaction:, exchanges:)
    sorted_exchanges = sort_projection_exchanges(exchanges)
    paid_installments = cash_transaction.cash_installments.order(:number).select(&:paid?)
    installments_count = sorted_exchanges.count

    cash_transaction.cash_installments.where(paid: false).delete_all
    cash_transaction.cash_installments.where(id: paid_installments.map(&:id)).update_all(cash_installments_count: installments_count)

    sorted_exchanges.drop(paid_installments.count).each_with_index do |exchange, index|
      cash_transaction.cash_installments.create!(
        number: paid_installments.count + index + 1,
        date: exchange.date,
        month: exchange.month,
        year: exchange.year,
        price: exchange.price,
        starting_price: exchange.price,
        cash_installments_count: installments_count
      )
    end
  end

  def rebuild_card_bound_projection_installments_preserving_paid!(cash_transaction:, exchanges:, projection_date: nil)
    paid_installments = cash_transaction.cash_installments.order(:number).select(&:paid?)
    remaining_price = cash_transaction.price - paid_installments.sum(&:price)
    installments_count = paid_installments.count + (remaining_price.zero? ? 0 : 1)

    cash_transaction.cash_installments.where(paid: false).delete_all
    cash_transaction.cash_installments.where(id: paid_installments.map(&:id)).update_all(cash_installments_count: installments_count)

    return if remaining_price.zero?

    projection_date ||= projection_cash_transaction_date(exchanges)

    cash_transaction.cash_installments.create!(
      number: paid_installments.count + 1,
      date: projection_date,
      month: projection_date.month,
      year: projection_date.year,
      price: remaining_price,
      starting_price: remaining_price,
      cash_installments_count: installments_count,
      paid: false
    )
  end

  def rebuild_card_bound_projection_installment!(cash_transaction:, exchanges:, projection_date: nil, paid_by_date: false)
    projection_price = exchanges.sum(&:price)
    projection_date ||= exchanges.min_by(&:date).date

    cash_transaction.cash_installments.create!(
      number: 1,
      date: projection_date,
      month: projection_date.month,
      year: projection_date.year,
      price: projection_price,
      starting_price: projection_price,
      cash_installments_count: 1,
      paid: paid_by_date ? (projection_date.present? && Time.zone.today >= projection_date) : false
    )
  end

  def projection_cash_transaction_date(exchanges)
    return exchanges.min_by(&:date).date unless card_bound?

    bucket_month, bucket_year = card_bound_projection_bucket_month_year(exchanges)
    reference = transactable.user_card.references.find_by(
      context: transactable.context,
      month: bucket_month,
      year: bucket_year
    )

    return reference.reference_date.end_of_day if reference.present?

    due_day = [ transactable.user_card.due_date_day, Time.days_in_month(bucket_month, bucket_year) ].min
    Time.zone.local(bucket_year, bucket_month, due_day).end_of_day
  end

  def assign_projection_cash_transaction_to_siblings!
    projection_exchanges.each do |exchange|
      exchange.cash_transaction = cash_transaction
    end
  end

  def projection_exchanges(excluding: nil)
    candidate_exchanges = merge_entity_transaction_exchange_candidates(excluding:)
    candidate_exchanges.reject! do |exchange|
      (exchange.id.present? && exchange.id == id) || exchange.equal?(self)
    end
    candidate_exchanges << self unless excluding.present? && excluding == self

    candidate_exchanges = candidate_exchanges.reject do |exchange|
      (excluding.present? && ((excluding.id.present? && exchange.id == excluding.id) || exchange.equal?(excluding))) || exchange.marked_for_destruction?
    end

    candidate_exchanges.select(&:monetary?).select { |exchange| same_projection_bucket?(exchange) }
  end

  def synchronized_projection_exchanges(cash_transaction:, excluding: nil)
    return projection_exchanges(excluding:) if standalone?

    in_memory_exchanges = in_memory_entity_transaction_exchanges
    candidate_exchanges = merge_projection_exchange_candidates(in_memory_exchanges:, cash_transaction:, excluding:)
    if !(excluding.present? && excluding == self) && candidate_exchanges.none? { |exchange| exchange.equal?(self) || (exchange.id.present? && exchange.id == id) }
      candidate_exchanges << self
    end

    candidate_exchanges = candidate_exchanges.reject do |exchange|
      (excluding.present? && ((excluding.id.present? && exchange.id == excluding.id) || exchange.equal?(excluding))) || exchange.marked_for_destruction?
    end

    candidate_exchanges.select(&:monetary?).select { |exchange| same_projection_group?(exchange, cash_transaction:) }
  end

  def projection_exchange_paid_state_available?(exchanges)
    exchanges.any? { |exchange| !exchange.replay_paid_state.nil? }
  end

  def projected_exchange_paid_state(exchange, paid_by_date:, paid_by_exchange:)
    return ActiveModel::Type::Boolean.new.cast(exchange.replay_paid_state) if paid_by_exchange && !exchange.replay_paid_state.nil?
    return exchange.date.present? && Time.zone.today >= exchange.date if paid_by_date

    false
  end

  def delete_projection_cash_transaction(cash_transaction)
    return unless cash_transaction&.persisted?

    cash_transaction.cash_installments.delete_all
    cash_transaction.delete
  end

  def projection_sync_relevant_change?
    (changes.keys - %w[created_at updated_at exchanges_count]).present?
  end

  def card_bound_projection_bucket_changed?
    card_bound? && cash_transaction.present? &&
      (cash_transaction.month != month || cash_transaction.year != year)
  end

  def rehome_card_bound_exchange_before_sync!
    previous_cash_transaction = cash_transaction
    sync_remaining_card_bound_projection_exchanges!(previous_cash_transaction)

    self.cash_transaction = nil
    create_cash_transaction
  end

  def sync_remaining_card_bound_projection_exchanges!(previous_cash_transaction)
    remaining_exchanges = Exchange.where(cash_transaction_id: previous_cash_transaction.id).where.not(id:).to_a.map do |exchange|
      in_memory_entity_transaction_exchanges.find { |candidate| candidate.id == exchange.id } || exchange
    end
    return if remaining_exchanges.empty?

    remaining_exchanges.first.send(
      :sync_projection_cash_transaction!,
      cash_transaction: previous_cash_transaction,
      exchanges: remaining_exchanges
    )
  end

  def editable_unpaid_projection_change?
    return false unless standalone?

    paid_installments = cash_transaction.cash_installments.order(:number).select(&:paid?)
    desired_rows = desired_projection_rows

    paid_installments.present? &&
      desired_rows.size >= paid_installments.size &&
      paid_prefix_unchanged?(paid_installments, desired_rows)
  end

  def editable_card_bound_projection_change?
    return false unless card_bound?

    paid_installments = cash_transaction.cash_installments.order(:number).select(&:paid?)
    paid_installments.present?
  end

  def editable_unpaid_projection_destruction?
    paid_installments_count = cash_transaction.cash_installments.where(paid: true).count
    return false if paid_installments_count.zero?

    sorted_exchanges = sort_projection_exchanges(Exchange.where(cash_transaction_id: cash_transaction.id).to_a)
    exchange_index = sorted_exchanges.find_index { |exchange| exchange.equal?(self) || (exchange.id.present? && exchange.id == id) }

    exchange_index.present? && exchange_index >= paid_installments_count
  end

  def projection_cash_transaction_without_paid_history?(cash_transaction)
    return true if cash_transaction.blank?

    cash_transaction.cash_installments.where(paid: true).none?
  end

  def projection_cash_transaction_price(cash_transaction:, exchanges:, current_projection_price: cash_transaction.price, removed_exchange: nil)
    return exchanges.sum(&:price) unless cash_transaction.cash_installments.where(paid: true).exists?

    current_projection_price + card_bound_projection_new_exchange_delta(cash_transaction:, exchanges:) - removed_exchange&.price.to_i
  end

  def card_bound_projection_new_exchange_delta(cash_transaction:, exchanges:)
    existing_exchange_ids = Exchange.where(cash_transaction_id: cash_transaction.id).pluck(:id).to_set

    exchanges.reject do |exchange|
      exchange.id.present? && existing_exchange_ids.include?(exchange.id)
    end.sum(&:price)
  end

  def shared_projection_cash_transaction
    return standalone_shared_projection_cash_transaction unless card_bound?

    preferred_card_bound_projection_cash_transaction(card_bound_visible_projection_cash_transactions) ||
      existing_card_bound_projection_cash_transaction
  end

  def projection_cash_transaction_params
    standalone? ? cash_transaction_params : card_bound_cash_transaction_params
  end

  def sync_projection_reference_transactable!(cash_transaction:)
    desired_reference = projection_reference_transactable
    return if desired_reference.blank?

    current_reference = cash_transaction.reference_transactable
    return if current_reference.present? &&
              current_reference.instance_of?(desired_reference.class) &&
              current_reference.id == desired_reference.id

    cash_transaction.update_columns(
      reference_transactable_type: desired_reference.class.name,
      reference_transactable_id: desired_reference.id
    )
  end

  def projection_reference_transactable
    return unless standalone?
    return unless transactable.respond_to?(:persisted?) && transactable.persisted?

    transactable
  end

  def projection_description
    return transactable.description if standalone?

    numeric_month_year = RefMonthYear.new(month, year).numeric_month_year
    "[ #{numeric_month_year} ] #{entity_transaction.entity.entity_name} - #{transactable.user_card.user_card_name}"
  end

  def existing_card_bound_projection_cash_transaction
    return if standalone?

    matched_cash_transaction = preferred_card_bound_projection_cash_transaction(
      candidate_card_bound_projection_cash_transactions.where(id: candidate_card_bound_projection_cash_transaction_ids)
    )
    return matched_cash_transaction if matched_cash_transaction.present?

    preferred_card_bound_projection_cash_transaction(
      candidate_card_bound_projection_cash_transactions.where(description: projection_description)
    )
  end

  def same_projection_bucket?(exchange)
    return true if standalone?

    exchange.month == month && exchange.year == year
  end

  def same_projection_group?(exchange, cash_transaction:)
    return same_projection_bucket?(exchange) if standalone?

    return same_projection_bucket?(exchange) if cash_transaction.present? &&
                                                ((exchange.cash_transaction_id.present? && exchange.cash_transaction_id == cash_transaction.id) ||
                                                 exchange.cash_transaction == cash_transaction)

    same_projection_bucket?(exchange)
  end

  def card_bound_projection_bucket_month_year(exchanges)
    matching_exchange = exchanges.find { |exchange| exchange.month == month && exchange.year == year }
    return [ matching_exchange.month, matching_exchange.year ] if matching_exchange.present?

    latest_exchange = exchanges.max_by { |exchange| [ exchange.year, exchange.month, exchange.number, exchange.date.to_i ] }
    [ latest_exchange.month, latest_exchange.year ]
  end

  def candidate_card_bound_projection_cash_transaction_ids
    Exchange.joins(:entity_transaction)
            .where(
              bound_type: :card_bound,
              month:,
              year:,
              entity_transactions: {
                entity_id: entity_transaction.entity_id,
                transactable_type: transactable.class.name
              }
            )
            .where.not(cash_transaction_id: nil)
            .distinct
            .pluck(:cash_transaction_id)
  end

  def candidate_card_bound_projection_cash_transactions
    transactable.context.cash_transactions.where(
      user_id: user.id,
      user_card_id: transactable.user_card_id,
      context_id: transactable.context_id,
      cash_transaction_type: model_name.name,
      month:,
      year:
    )
  end

  def preferred_card_bound_projection_cash_transaction(scope)
    scope.includes(:cash_installments, :exchanges).to_a.max_by do |cash_transaction|
      [
        cash_transaction.cash_installments.any? { |installment| !installment.paid? } ? 1 : 0,
        cash_transaction.exchanges.size,
        cash_transaction.cash_installments.any?(&:paid?) ? 1 : 0,
        cash_transaction.cash_installments.size,
        cash_transaction.updated_at.to_i,
        cash_transaction.id
      ]
    end
  end

  def standalone_shared_projection_cash_transaction
    projection_exchanges.filter_map(&:cash_transaction).find(&:present?) ||
      entity_transaction.exchanges.where.not(id: id).where.not(cash_transaction_id: nil).to_a.select do |exchange|
        same_projection_bucket?(exchange)
      end.first&.cash_transaction ||
      existing_card_bound_projection_cash_transaction
  end

  def card_bound_visible_projection_cash_transactions
    visible_candidate_ids = projection_exchanges.filter_map(&:cash_transaction_id)
    visible_candidate_ids.concat(
      entity_transaction.exchanges.where.not(id: id).where.not(cash_transaction_id: nil).to_a.select do |exchange|
        same_projection_bucket?(exchange)
      end.filter_map(&:cash_transaction_id)
    )
    visible_candidate_ids << existing_card_bound_projection_cash_transaction&.id

    candidate_card_bound_projection_cash_transactions.where(id: visible_candidate_ids.compact.uniq)
  end

  def desired_projection_rows
    sort_projection_exchanges(synchronized_projection_exchanges(cash_transaction:)).each_with_index.map do |exchange, index|
      {
        number: index + 1,
        date: exchange.date,
        month: exchange.month,
        year: exchange.year,
        price: exchange.price
      }
    end
  end

  def paid_prefix_unchanged?(paid_installments, desired_rows)
    paid_installments.each_with_index.all? do |installment, index|
      desired_row = desired_rows[index]

      desired_row[:number] == installment.number &&
        desired_row[:date] == installment.date &&
        desired_row[:month] == installment.month &&
        desired_row[:year] == installment.year &&
        desired_row[:price] == installment.price
    end
  end

  def remove_paid_projection_exchanges(sorted_exchanges, paid_installments)
    remaining_exchanges = sorted_exchanges.dup

    paid_installments.each do |installment|
      matched_index = remaining_exchanges.find_index do |exchange|
        projection_row_matches_installment?(exchange, installment)
      end
      remaining_exchanges.delete_at(matched_index) if matched_index.present?
    end

    remaining_exchanges
  end

  def projection_row_matches_installment?(exchange, installment)
    exchange.number == installment.number &&
      exchange.date == installment.date &&
      exchange.month == installment.month &&
      exchange.year == installment.year &&
      exchange.price == installment.price
  end

  def sort_projection_exchanges(exchanges)
    exchanges.sort_by do |exchange|
      [ exchange.date, exchange.number, exchange.persisted? ? 0 : 1, exchange.id || Float::INFINITY ]
    end
  end

  def in_memory_entity_transaction_exchanges
    entity_transaction.exchanges.to_a.uniq { |exchange| exchange.id || exchange.object_id }
  end

  def merge_entity_transaction_exchange_candidates(excluding:)
    in_memory_exchanges = in_memory_entity_transaction_exchanges
    in_memory_exchange_ids = in_memory_exchanges.filter_map(&:id).to_set
    persisted_siblings = entity_transaction.exchanges.where.not(id: [ excluding&.id, id ].compact).to_a.reject do |exchange|
      in_memory_exchange_ids.include?(exchange.id)
    end

    in_memory_exchanges + persisted_siblings
  end

  def merge_projection_exchange_candidates(in_memory_exchanges:, cash_transaction:, excluding:)
    return in_memory_exchanges if cash_transaction.blank?

    in_memory_exchange_ids = in_memory_exchanges.filter_map(&:id).to_set
    persisted_projection_exchanges = Exchange.where(cash_transaction_id: cash_transaction.id).where.not(id: excluding&.id).to_a.reject do |exchange|
      in_memory_exchange_ids.include?(exchange.id)
    end

    in_memory_exchanges + persisted_projection_exchanges
  end
end
