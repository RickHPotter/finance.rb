# frozen_string_literal: true

# Shared functionality for models that can produce CashTransactions.
module ExchangeCashTransactable
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
    return if (changes.keys - %w[created_at updated_at]).empty?

    errors.add(:base, :paid_history_locked)
    throw(:abort)
  end

  def prevent_locked_projection_destruction
    return unless cash_transaction&.paid_history?

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
    sync_projection_cash_transaction!(cash_transaction:)
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

    return if (changes.keys - %w[created_at updated_at]).empty?

    assign_projection_cash_transaction_to_siblings!
    sync_projection_cash_transaction!(cash_transaction:)
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

    remaining_exchanges = projection_exchanges(excluding: self)

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
    sibling_exchanges = projection_exchanges(excluding: self)

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
    previous_cash_transaction&.destroy if previous_cash_transaction&.persisted?
  end

  def remember_projection_cash_transaction_id
    self.destroyed_projection_cash_transaction_id = cash_transaction_id
  end

  def cleanup_orphaned_projection_cash_transaction
    return if destroyed_projection_cash_transaction_id.blank?
    return if Exchange.where(cash_transaction_id: destroyed_projection_cash_transaction_id).exists?

    CashTransaction.find_by(id: destroyed_projection_cash_transaction_id)&.destroy
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
  end

  def rebuild_projection_installments!(cash_transaction:, exchanges:)
    raise "Cannot rebuild paid projection installments" if cash_transaction.cash_installments.where(paid: true).exists?

    cash_transaction.cash_installments.destroy_all
    installments_count = exchanges.count

    exchanges.sort_by { |exchange| [ exchange.number, exchange.date ] }.each_with_index do |exchange, index|
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

  def assign_projection_cash_transaction_to_siblings!
    projection_exchanges.each do |exchange|
      exchange.cash_transaction = cash_transaction
    end
  end

  def projection_exchanges(excluding: nil)
    [ *entity_transaction.exchanges.to_a, self ].uniq.reject(&:marked_for_destruction?).select(&:monetary?).reject do |exchange|
      excluding.present? && exchange == excluding
    end
  end

  def shared_projection_cash_transaction
    projection_exchanges.filter_map(&:cash_transaction).find(&:present?) ||
      entity_transaction.exchanges.where.not(id: id).where.not(cash_transaction_id: nil).pick(:cash_transaction_id).then do |cash_transaction_id|
        CashTransaction.find_by(id: cash_transaction_id)
      end
  end

  def projection_cash_transaction_params
    standalone? ? cash_transaction_params : card_bound_cash_transaction_params
  end

  def projection_description
    return transactable.description if standalone?

    numeric_month_year = RefMonthYear.new(month, year).numeric_month_year
    "[ #{numeric_month_year} ] #{entity_transaction.entity.entity_name} - #{transactable.user_card.user_card_name}"
  end
end
