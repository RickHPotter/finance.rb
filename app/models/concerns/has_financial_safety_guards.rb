# frozen_string_literal: true

# Shared write-layer guards for transactions backed by installments.
module HasFinancialSafetyGuards # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  CONFIRMATION_HISTORY_ERROR_KEYS = %i[
    same_cycle_history_correction_confirmation_required
    same_month_paid_state_correction_confirmation_required
    month_boundary_history_correction_confirmation_required
    exchange_return_price_correction_confirmation_required
    paid_amount_correction_confirmation_required
  ].freeze

  included do
    # @validations ............................................................
    validate :prevent_unsafe_paid_history_rewrites, on: :update

    # @callbacks ..............................................................
    before_destroy :prevent_destroy_when_paid_history_is_locked, prepend: true
  end

  def historical_correction_confirmation_prompt?
    Array(errors.details[:base]).any? { |detail| CONFIRMATION_HISTORY_ERROR_KEYS.include?(detail[:error]) }
  end

  def historical_correction_confirmation_error_key
    Array(errors.details[:base]).map { |detail| detail[:error] }.find { |key| CONFIRMATION_HISTORY_ERROR_KEYS.include?(key) }
  end

  # @private_instance_methods .................................................

  private

  def prevent_unsafe_paid_history_rewrites
    return unless persisted?
    return unless paid_history? || paid_projection_target_rewrite_attempted?

    add_allocation_history_error if allocation_changed_after_payment?

    history_error_key = current_installment_history_error_key
    errors.add(:base, history_error_key) if history_error_key.present?
  end

  def prevent_destroy_when_paid_history_is_locked
    return unless destroy_locked_by_history?
    return if confirmed_destroy_with_history?

    errors.add(:base, destroy_history_error_key)
    throw(:abort)
  end

  def current_installment_history_error_key
    return if shared_paid_state_toggle_only?
    return if actionable_shared_return_correction?
    return if editable_shared_return_structure_change_after_payment?
    return if confirmed_historical_correction?
    return confirmation_history_error_key if historical_correction_confirmation_required?

    installment_history_error_key if unsafe_installment_rewrite_attempted?
  end

  def unsafe_installment_rewrite_attempted?
    return false if shared_paid_state_toggle_only?
    return false if actionable_shared_return_correction?
    return false if editable_shared_return_structure_change_after_payment?
    return true if paid_projection_target_rewrite_attempted?
    return true if parent_financial_fields_changed_for_lock?
    return false unless installment_structure_changed?
    return true if paid_installment_rewrite_attempted?

    !can_edit_unpaid_future_installments?(editable_installment_dates)
  end

  def paid_projection_target_rewrite_attempted?
    return card_paid_invoice_cycle_rewrite_attempted? if is_a?(CardTransaction)

    installments.any? do |installment|
      next false unless installment.changed?
      next false unless installment.respond_to?(:target_cash_transaction_for_rewrite, true)

      target_cash_transaction = installment.send(:target_cash_transaction_for_rewrite)
      next false if target_cash_transaction.blank? || target_cash_transaction.id == installment.cash_transaction_id

      target_cash_transaction.paid_history?
    end
  end

  def card_paid_invoice_cycle_rewrite_attempted?
    installments.any? do |installment|
      next false unless installment.persisted? && installment.changed?
      next false if installment.date.blank?

      target_reference = user_card.find_or_create_reference_for(installment.date, context:)
      target_cash_transaction = context.cash_transactions.find_by(
        cash_transaction_type: "CardInstallment",
        user_card_id: user_card_id,
        month: target_reference.month,
        year: target_reference.year
      )

      next false if target_cash_transaction.blank? || target_cash_transaction.id == installment.cash_transaction_id

      target_cash_transaction.paid_history?
    end
  end

  def allocation_changed_after_payment?
    return false unless original_categories.present? || original_entities.present?

    !can_change_allocation? && allocation_changed?
  end

  def allocation_changed?
    original_category_ids != current_category_ids || original_entity_ids != current_entity_ids
  end

  def installment_structure_changed?
    installments.any? { |installment| installment.marked_for_destruction? || installment.new_record? || installment.changed? }
  end

  def paid_installment_rewrite_attempted?
    installments.any? do |installment|
      next false unless installment.persisted? && installment_previously_paid?(installment)
      next false if shared_paid_toggle_only_for?(installment)

      installment.marked_for_destruction? || installment.changed?
    end
  end

  def shared_paid_state_toggle_only?
    return false unless shared_paid_state_flow?
    return false if parent_financial_fields_changed?
    return false if allocation_changed_after_payment?
    return false if installments.any?(&:marked_for_destruction?)
    return false if installments.any?(&:new_record?)

    changed_installments = installments.select(&:changed?)
    return false if changed_installments.empty?

    changed_installments.all? { |installment| shared_paid_toggle_only_for?(installment) }
  end

  def shared_paid_toggle_only_for?(installment)
    installment.changes.except("updated_at").keys == [ "paid" ]
  end

  def shared_paid_state_flow?
    return false unless respond_to?(:shared_return_flow?)

    shared_return_flow?
  end

  def editable_installment_dates
    installments.filter_map do |installment|
      next if installment.persisted? && installment.paid?
      next if installment.marked_for_destruction?

      installment.date
    end
  end

  def editable_shared_return_structure_change_after_payment?
    return false unless is_a?(CashTransaction)
    return false unless shared_paid_state_flow?
    return false if allocation_changed_after_payment?
    return false unless installment_structure_changed? || parent_financial_fields_changed?

    paid_installments_unchanged? && can_edit_unpaid_future_installments?(editable_installment_dates)
  end

  def actionable_shared_return_correction?
    return false unless is_a?(CashTransaction)
    return false unless shared_paid_state_flow?
    return false if source_message_id.blank?
    return false if allocation_changed_after_payment?
    return false unless installment_structure_changed? || parent_financial_fields_changed?

    true
  end

  def paid_installments_unchanged?
    installments.none? do |installment|
      next false unless installment_previously_paid?(installment)

      installment.marked_for_destruction? || installment.changes.except("updated_at").present?
    end
  end

  def parent_financial_fields_changed?
    will_save_change_to_date? || will_save_change_to_month? || will_save_change_to_year? || will_save_change_to_price?
  end

  def parent_financial_fields_changed_for_lock?
    return false if historical_correction_candidate?

    parent_financial_fields_changed?
  end

  def original_category_ids
    Array(original_categories).presence || current_category_ids
  end

  def original_entity_ids
    Array(original_entities).presence || current_entity_ids
  end

  def current_category_ids
    category_transactions.map(&:category_id).compact.sort
  end

  def current_entity_ids
    entity_transactions.map(&:entity_id).compact.sort
  end

  def add_allocation_history_error
    errors.add(:base, allocation_history_error_key)
  end

  def add_installment_history_error
    errors.add(:base, installment_history_error_key)
  end

  def historical_correction_confirmation_required?
    historical_correction_candidate? && !historical_correction_confirmation_requested?
  end

  def confirmed_historical_correction?
    historical_correction_candidate? && historical_correction_confirmation_requested?
  end

  def historical_correction_candidate?
    return false if allocation_changed_after_payment?
    return false if installments.any?(&:marked_for_destruction?)
    return false if installments.any?(&:new_record?)
    return true if exchange_return_paid_price_correction_candidate?
    return true if general_paid_amount_correction_candidate?
    return false if will_save_change_to_price?
    return false if changed_installments.empty?

    if is_a?(CardTransaction)
      same_cycle_historical_correction_candidate?
    elsif is_a?(CashTransaction)
      same_month_paid_state_correction_candidate? || month_boundary_historical_correction_candidate?
    else
      false
    end
  end

  def changed_installments
    installments.select(&:changed?)
  end

  def same_month_paid_state_correction_candidate?
    return false unless changed_installments.all?(&:persisted?)

    changed_installments.all? do |installment|
      keys = installment.changes.except("updated_at").keys
      next false unless keys == [ "paid" ]
      next false unless installment_previously_paid?(installment)

      installment_month = installment.attribute_in_database("month") || installment.month
      installment_year = installment.attribute_in_database("year") || installment.year
      unpaid_now = !ActiveModel::Type::Boolean.new.cast(installment.paid)

      installment_month.to_i == Time.zone.today.month &&
        installment_year.to_i == Time.zone.today.year &&
        unpaid_now
    end
  end

  def same_cycle_historical_correction_candidate?
    return false unless changed_installments.all?(&:persisted?)

    changed_installments.all? do |installment|
      keys = installment.changes.except("updated_at").keys
      next false unless keys.all? { |key| %w[date month year].include?(key) }
      next false unless installment_previously_paid?(installment)

      month_unchanged = !installment.will_save_change_to_month?
      year_unchanged = !installment.will_save_change_to_year?

      month_unchanged && year_unchanged
    end
  end

  def month_boundary_historical_correction_candidate?
    return false unless changed_installments.all?(&:persisted?)

    changed_installments.all? do |installment|
      keys = installment.changes.except("updated_at").keys
      next false unless keys.all? { |key| %w[date month year].include?(key) }
      next false unless installment_previously_paid?(installment)

      period_distance_in_months(installment) <= 1
    end
  end

  def exchange_return_paid_price_correction_candidate?
    return false unless is_a?(CashTransaction)
    return false unless exchange_return?
    return false unless changed_installments.all?(&:persisted?)
    return false if changed_installments.empty?

    changed_installments.all? { |installment| installment.changes.except("updated_at").keys == [ "price" ] } &&
      changed_installments.any? { |installment| installment_previously_paid?(installment) }
  end

  def general_paid_amount_correction_candidate?
    return false unless changed_installments.all?(&:persisted?)
    return false if changed_installments.empty?
    return false if is_a?(CashTransaction) && exchange_return_paid_price_correction_candidate?
    return false if will_save_change_to_date? || will_save_change_to_month? || will_save_change_to_year?
    return false unless changed_installments.all? { |installment| installment.changes.except("updated_at").keys == [ "price" ] }
    return false unless changed_installments.any? { |installment| installment_previously_paid?(installment) }
    return false if will_save_change_to_price? && current_installment_total != price

    true
  end

  def current_installment_total
    installments.reject(&:marked_for_destruction?).sum { |installment| installment.price.to_i }
  end

  def installment_previously_paid?(installment)
    return installment.paid? unless installment.respond_to?(:saved_change_to_paid?)

    installment.attribute_in_database("paid").nil? ? installment.paid? : ActiveModel::Type::Boolean.new.cast(installment.attribute_in_database("paid"))
  end

  def period_distance_in_months(installment)
    old_year = installment.attribute_in_database("year") || installment.year
    old_month = installment.attribute_in_database("month") || installment.month
    new_year = installment.year
    new_month = installment.month

    ((new_year.to_i * 12) + new_month.to_i) - ((old_year.to_i * 12) + old_month.to_i)
  end

  def historical_correction_confirmation_requested?
    ActiveModel::Type::Boolean.new.cast(historical_correction_confirmation)
  end

  def confirmed_destroy_with_history?
    destroy_confirmation_candidate? && historical_correction_confirmation_requested?
  end

  def destroy_confirmation_candidate?
    return true if is_a?(CashTransaction)
    return card_destroy_confirmation_candidate? if is_a?(CardTransaction) && card_destroy_locked_by_settlement_history?

    false
  end

  def destroy_locked_by_history?
    return card_destroy_locked_by_settlement_history? if is_a?(CardTransaction)
    return true if paid_history?

    false
  end

  def card_destroy_confirmation_candidate?
    affected_card_cycles.all? do |month, year|
      remaining_cycle_total = remaining_card_cycle_total(month:, year:)
      remaining_cycle_total >= remaining_cycle_settled_amount(month:, year:)
    end
  end

  def affected_card_cycles
    card_cycle_source_rows.filter_map do |row|
      month = cycle_row_value(row, :month)
      year = cycle_row_value(row, :year)
      next if month.blank? || year.blank?

      [ month, year ]
    end.uniq
  end

  def card_cycle_source_rows
    Array(original_installment_projection_rows).presence || Array(original_installments).presence || installments
  end

  def cycle_row_value(row, key)
    row.respond_to?(key) ? row.public_send(key) : row[key]
  end

  def remaining_card_cycle_total(month:, year:)
    CardInstallment.joins(:card_transaction)
                   .where(card_transactions: { context_id:, user_card_id: })
                   .where(month:, year:)
                   .where.not(card_transaction_id: id)
                   .sum(:price)
                   .abs
  end

  def remaining_cycle_settled_amount(month:, year:)
    remaining_invoice_paid_amount(month:, year:) + remaining_advance_paid_amount(month:, year:)
  end

  def remaining_invoice_paid_amount(month:, year:)
    return 0 if remaining_card_cycle_total(month:, year:).zero?

    relevant_invoice_cash_transactions_for_cycle(month:, year:).sum do |invoice|
      invoice.cash_installments.where(paid: true).sum(:price).abs
    end
  end

  def invoice_cash_transaction_for_cycle(month:, year:)
    context.cash_transactions.find_by(cash_transaction_type: "CardInstallment", user_card_id:, month:, year:)
  end

  def relevant_invoice_cash_transactions_for_cycle(month:, year:)
    transactions = card_cycle_source_rows.filter_map do |row|
      next unless cycle_row_value(row, :month).to_i == month.to_i
      next unless cycle_row_value(row, :year).to_i == year.to_i

      cash_transaction_id = cycle_row_value(row, :cash_transaction_id)
      next if cash_transaction_id.blank?

      CashTransaction.find_by(id: cash_transaction_id)
    end.uniq

    return transactions if transactions.present?

    Array(invoice_cash_transaction_for_cycle(month:, year:)).compact
  end

  def remaining_advance_paid_amount(month:, year:)
    paid_card_advance_transactions_for_cycle(month:, year:)
      .reject { |transaction| transaction.id == id }
      .sum do |transaction|
      advance_cash_transaction = transaction.advance_cash_transaction
      next 0 unless advance_cash_transaction

      advance_cash_transaction.cash_installments.where(paid: true).sum(:price).abs
    end
  end

  def card_destroy_locked_by_settlement_history?
    affected_card_cycles.any? do |month, year|
      relevant_invoice_cash_transactions_for_cycle(month:, year:).any?(&:paid_history?) ||
        paid_card_advance_transactions_for_cycle(month:, year:).any?
    end
  end

  def paid_card_advance_transactions_for_cycle(month:, year:)
    context.card_transactions
           .joins(:categories)
           .where(user_card_id:, month:, year:, categories: { category_name: "CARD ADVANCE" })
           .distinct
           .select { |transaction| transaction.advance_cash_transaction&.paid_history? }
  end

  def confirmation_history_error_key
    if is_a?(CashTransaction) && exchange_return_paid_price_correction_candidate?
      :exchange_return_price_correction_confirmation_required
    elsif general_paid_amount_correction_candidate?
      :paid_amount_correction_confirmation_required
    elsif is_a?(CardTransaction)
      :same_cycle_history_correction_confirmation_required
    elsif is_a?(CashTransaction) && same_month_paid_state_correction_candidate?
      :same_month_paid_state_correction_confirmation_required
    elsif is_a?(CashTransaction)
      :month_boundary_history_correction_confirmation_required
    end
  end

  def allocation_history_error_key
    :allocation_locked_after_payment
  end

  def installment_history_error_key
    :paid_history_locked
  end

  def destroy_history_error_key
    :destroy_locked_after_payment
  end
end
