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
    return unless cash_transaction&.paid_history?
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
    self.cash_transaction = shared_projection_cash_transaction || CashTransaction.create(projection_cash_transaction_params)
    assign_projection_cash_transaction_to_siblings!
    sync_projection_cash_transaction!(cash_transaction:, exchanges: synchronized_projection_exchanges(cash_transaction:))
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
      sync_projection_cash_transaction!(cash_transaction:, exchanges: remaining_exchanges)
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
      sync_projection_cash_transaction!(cash_transaction:, exchanges: sibling_exchanges)
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

  def sync_projection_cash_transaction!(cash_transaction:, exchanges: projection_exchanges)
    return _destroy_cash_transaction if exchanges.empty?

    projection_price = exchanges.sum(&:price)
    return _destroy_cash_transaction if projection_price.zero?

    projection_date = exchanges.min_by(&:date).date

    cash_transaction.update_columns(
      description: projection_description,
      starting_price: projection_price,
      price: projection_price,
      date: projection_date,
      month: projection_date.month,
      year: projection_date.year
    )

    rebuild_projection_installments!(cash_transaction:, exchanges:)
    cash_transaction.update_columns(
      cash_installments_count: cash_transaction.cash_installments.count,
      paid: cash_transaction.cash_installments.where(paid: false).none?
    )
    sync_projection_reference_transactable!(cash_transaction:)
  end

  def rebuild_projection_installments!(cash_transaction:, exchanges:)
    if cash_transaction.cash_installments.where(paid: true).exists?
      raise "Cannot rebuild paid projection installments" unless standalone? && editable_unpaid_projection_change?

      return rebuild_standalone_projection_installments_preserving_paid!(cash_transaction:, exchanges:)
    end

    cash_transaction.cash_installments.delete_all
    return rebuild_card_bound_projection_installment!(cash_transaction:, exchanges:) if card_bound?

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
        cash_installments_count: installments_count
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

  def rebuild_card_bound_projection_installment!(cash_transaction:, exchanges:)
    projection_price = exchanges.sum(&:price)
    projection_date = exchanges.min_by(&:date).date

    cash_transaction.cash_installments.create!(
      number: 1,
      date: projection_date,
      month: projection_date.month,
      year: projection_date.year,
      price: projection_price,
      starting_price: projection_price,
      cash_installments_count: 1
    )
  end

  def assign_projection_cash_transaction_to_siblings!
    projection_exchanges.each do |exchange|
      exchange.cash_transaction = cash_transaction
    end
  end

  def projection_exchanges(excluding: nil) # rubocop:disable Metrics/AbcSize
    persisted_siblings = entity_transaction.exchanges.where.not(id: [ excluding&.id, id ].compact).to_a
    in_memory_exchanges = entity_transaction.exchanges.to_a
    candidate_exchanges = (persisted_siblings + in_memory_exchanges).uniq { |exchange| exchange.id || exchange.object_id }
    candidate_exchanges.reject! do |exchange|
      (exchange.id.present? && exchange.id == id) || exchange.equal?(self)
    end
    candidate_exchanges << self unless excluding.present? && excluding == self

    candidate_exchanges = candidate_exchanges.reject do |exchange|
      (excluding.present? && ((excluding.id.present? && exchange.id == excluding.id) || exchange.equal?(excluding))) || exchange.marked_for_destruction?
    end

    candidate_exchanges.select(&:monetary?).select { |exchange| same_projection_bucket?(exchange) }
  end

  def synchronized_projection_exchanges(cash_transaction:, excluding: nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    return projection_exchanges(excluding:) if standalone?

    in_memory_exchanges = entity_transaction.exchanges.to_a
    persisted_projection_exchanges = cash_transaction.present? ? Exchange.where(cash_transaction_id: cash_transaction.id).where.not(id: excluding&.id).to_a : []
    candidate_exchanges = (in_memory_exchanges + persisted_projection_exchanges).uniq { |exchange| exchange.id || exchange.object_id }
    if !(excluding.present? && excluding == self) && candidate_exchanges.none? { |exchange| exchange.equal?(self) || (exchange.id.present? && exchange.id == id) }
      candidate_exchanges << self
    end

    candidate_exchanges = candidate_exchanges.reject do |exchange|
      (excluding.present? && ((excluding.id.present? && exchange.id == excluding.id) || exchange.equal?(excluding))) || exchange.marked_for_destruction?
    end

    candidate_exchanges.select(&:monetary?).select { |exchange| same_projection_bucket?(exchange) }
  end

  def delete_projection_cash_transaction(cash_transaction)
    return unless cash_transaction&.persisted?

    cash_transaction.cash_installments.delete_all
    cash_transaction.delete
  end

  def projection_sync_relevant_change?
    (changes.keys - %w[created_at updated_at exchanges_count]).present?
  end

  def editable_unpaid_projection_change?
    return false unless standalone?

    paid_installments = cash_transaction.cash_installments.order(:number).select(&:paid?)
    desired_rows = desired_projection_rows

    paid_installments.present? &&
      desired_rows.size >= paid_installments.size &&
      paid_prefix_unchanged?(paid_installments, desired_rows)
  end

  def shared_projection_cash_transaction
    if card_bound? && projection_exchanges.filter_map(&:cash_transaction).exclude?(existing_card_bound_projection_cash_transaction)
      return existing_card_bound_projection_cash_transaction
    end

    projection_exchanges.filter_map(&:cash_transaction).find(&:present?) ||
      entity_transaction.exchanges.where.not(id: id).where.not(cash_transaction_id: nil).to_a.select do |exchange|
        same_projection_bucket?(exchange)
      end.first&.cash_transaction ||
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

    transactable.context.cash_transactions
                .where(
                  user_id: user.id,
                  user_card_id: transactable.user_card_id,
                  context_id: transactable.context_id,
                  cash_transaction_type: model_name.name,
                  description: projection_description
                )
                .order(:id)
                .first
  end

  def same_projection_bucket?(exchange)
    return true if standalone?

    exchange.month == month && exchange.year == year
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

  def sort_projection_exchanges(exchanges)
    exchanges.sort_by do |exchange|
      [ exchange.date, exchange.number, exchange.persisted? ? 0 : 1, exchange.id || Float::INFINITY ]
    end
  end
end
