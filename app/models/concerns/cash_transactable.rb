# frozen_string_literal: true

# Shared functionality for models that are accumulated to a single CashTransaction.
module CashTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :previous_cash_transaction_id

    # @relationships ..........................................................
    belongs_to :cash_transaction, optional: true

    # @callbacks ..............................................................
    before_save :prevent_paid_cash_transaction_rewrite
    before_save :attach_cash_transaction
    after_save :fix_cash_transaction, :update_cash_transaction
    before_destroy :prevent_paid_cash_transaction_destroy, prepend: true
    after_destroy :update_or_destroy_cash_transaction
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def prevent_paid_cash_transaction_rewrite
    return unless rewrite_locked_paid_cash_transaction?

    errors.add(:base, :paid_history_locked)
    throw(:abort)
  end

  def prevent_paid_cash_transaction_destroy
    return if context_destroying?
    return unless current_cash_transaction_paid_history?
    return if confirmed_destroy_with_history?

    errors.add(:base, :destroy_locked_after_payment)
    throw(:abort)
  end

  # Assigns a `previous_cash_transaction_id` and attachs `cash_transaction` to `self`, based on certain attributes, and links it to `self`.
  #
  # @note This is a method that is called before_save.
  #
  # @see {CashTransaction}.
  #
  # @return [void].
  #
  def attach_cash_transaction
    return if rewrite_locked_paid_cash_transaction?

    self.previous_cash_transaction_id = cash_transaction_id
    self.cash_transaction = existing_projection_cash_transaction_to_attach || CashTransaction.create(new_cash_transaction_params)
  end

  # Deals with change of `cash_transaction` due to change of self FKs, by performing necessary operations to the `previous_cash_transaction`
  # when such is switched to another `cash_transaction`.
  #
  # @note This is a method that is called before_save.
  #
  # @see {CashTransaction}.
  #
  # @return [void].
  #
  def fix_cash_transaction
    return if previous_cash_transaction_id.nil?
    return if previous_cash_transaction_id == cash_transaction_id

    previous_cash_transaction = CashTransaction.find_by(id: previous_cash_transaction_id)
    return unless previous_cash_transaction

    association_name = previous_cash_transaction.cash_transaction_type.underscore.pluralize
    all_transactables = previous_cash_transaction.public_send(association_name)
    remaining_transactables = all_transactables.where.not(id:)

    if remaining_transactables.any?
      new_price = remaining_transactables.sum(:price)
      new_comment = remaining_transactables.first.comment
      previous_cash_transaction.update_columns(price: new_price, comment: new_comment)
      if previous_cash_transaction.cash_installments.any?
        previous_cash_transaction.cash_installments.first.update_columns(price: new_price)

        Logic::RecalculateBalancesService.new(
          user:,
          context: previous_cash_transaction.context,
          year: previous_cash_transaction.year,
          month: previous_cash_transaction.month
        ).call
      end
    else
      destroy_projection_cash_transaction(previous_cash_transaction)
    end
  end

  # Updates the associated `cash_transaction` with `self` model details.
  #
  # Updates the associated `cash_transaction` with the sum of `price`s,
  # updating also `comment` describing the days of associated `self`s.
  #
  # @note This is a method that is called after_save.
  #
  # @see {CashTransaction}.
  #
  # @return [void].
  #
  def update_cash_transaction
    cash_transaction.update_columns(description: cash_transaction_description, price: full_price, comment:)
    cash_transaction.cash_installments.first.update_columns(price: full_price)
  end

  # Updates or destroys the associated `cash_transaction` based on `self`s count.
  #
  # Checks the `count` of associated `self`s.
  # In case it is zero, it destroys the associated `cash_transaction`.
  # Otherwise, it updates the `cash_transaction` using {#update_cash_transaction}.
  #
  # @note This is a method that is called after_destroy.
  #
  # @see {#update_cash_transaction}.
  #
  # @return [void].
  #
  def update_or_destroy_cash_transaction
    return if cash_transaction.nil?

    transactable = cash_transaction.public_send(model_name.plural)
    if transactable.none?
      destroy_projection_cash_transaction(cash_transaction)
    else
      update_cash_transaction
    end
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `cash_transaction`.
  #
  def cash_transaction_params
    {
      description: cash_transaction_description,
      month:,
      year:,
      user_id:,
      cash_transaction_type: model_name.name,
      context_id: resolved_context_id,
      category_transactions:,
      investment_type_id: (investment_type_id if respond_to? :investment_type_id),
      user_card_id: (user_card_id if respond_to? :user_card_id),
      user_bank_account_id: (user_bank_account_id if respond_to? :user_bank_account_id)
    }.compact_blank
  end

  def new_cash_transaction_params
    if is_a?(Investment)
      paid = true
      reference_date = Time.zone.today.beginning_of_month
    elsif is_a?(CardInstallment)
      reference_date = card_payment_date
      paid = reference_date.present? && Time.zone.today >= reference_date
    else
      paid = (respond_to?(:paid) && paid) || (date.present? && Time.zone.today >= date)
      reference_date = card_payment_date
    end

    cash_transaction_params
      .without(:category_transactions)
      .merge(price:,
             date: reference_date,
             category_transactions_attributes:,
             entity_transactions_attributes:,
             cash_installments_attributes: [
               { number: 1, price: full_price * - 1, installment_type: :CashTransaction, date: card_payment_date.end_of_day, month:, year:, paid: }
             ])
  end

  def full_price
    return price if cash_transaction.nil?

    transactable = cash_transaction.public_send(model_name.plural)
    transactable.sum(:price)
  end

  def resolved_context
    return context if respond_to?(:context) && context.present?
    return transactable.context if respond_to?(:transactable) && transactable.respond_to?(:context)

    user.ensure_main_context!
  end

  def resolved_context_id
    return context_id if respond_to?(:context_id) && context_id.present?
    return transactable.context_id if respond_to?(:transactable) && transactable.respond_to?(:context_id)

    resolved_context.id
  end

  def rewrite_locked_paid_cash_transaction?
    return false unless protect_paid_cash_transaction_projection?
    return false if allow_new_projection_for_locked_paid_target?
    return false unless new_record? || changed?
    return false if same_cash_transaction_projection_target?

    current_cash_transaction_paid_history? || target_cash_transaction_paid_history?
  end

  def same_cash_transaction_projection_target?
    target_cash_transaction = target_cash_transaction_for_rewrite
    return false if target_cash_transaction.blank? || cash_transaction_id.blank?

    target_cash_transaction.id == cash_transaction_id
  end

  def current_cash_transaction_paid_history?
    return false unless protect_paid_cash_transaction_projection?

    cash_transaction&.paid_history?
  end

  def context_destroying?
    return context.destroying_for_removal? if respond_to?(:context) && context.present?
    return false unless respond_to?(:transactable)

    transactable.respond_to?(:context_destroying?, true) && transactable.send(:context_destroying?)
  end

  def confirmed_destroy_with_history?
    return false unless respond_to?(:transactable)

    transactable.respond_to?(:confirmed_destroy_with_history?, true) &&
      transactable.send(:confirmed_destroy_with_history?)
  end

  def target_cash_transaction_paid_history?
    return false unless protect_paid_cash_transaction_projection?

    target_cash_transaction_for_rewrite&.paid_history?
  end

  def target_cash_transaction_for_rewrite
    resolved_context.cash_transactions
                    .joins(:category_transactions)
                    .find_by(cash_transaction_params.without(:description))
  end

  def existing_projection_cash_transaction_to_attach
    return if allow_new_projection_for_locked_paid_target?

    target_cash_transaction_for_rewrite
  end

  def allow_new_projection_for_locked_paid_target?
    new_record? && is_a?(CardInstallment) && target_cash_transaction_paid_history?
  end

  def protect_paid_cash_transaction_projection?
    true
  end

  def destroy_projection_cash_transaction(record)
    return unless record
    return if record.destroyed?

    destroyed = record.destroy
    return if destroyed || protect_paid_cash_transaction_projection?

    Installment.where(cash_transaction_id: record.id).delete_all
    CashTransaction.where(id: record.id).delete_all
  end
end
