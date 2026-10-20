# frozen_string_literal: true

module NoncreditCardTransaction
  extend ActiveSupport::Concern

  included do
    validate :validate_noncredit_installments
    validate :prevent_cross_kind_card_change, on: :update
  end

  private

  def update_month_year
    return if destroyed? || subscription_id.present?

    if user_card&.prepaid? || user_card&.debit?
      self.year = date.year
      self.month = date.month
      return
    end

    cash_transaction = card_installments.order(:year, :month, :date).first.cash_transaction
    self.year = cash_transaction.date.year
    self.month = cash_transaction.date.month
  end

  def assign_noncredit_period
    return if date.blank?

    self.month = date.month
    self.year = date.year
    card_installments.each do |installment|
      next if installment.marked_for_destruction?

      installment.date = date
      installment.month = date.month
      installment.year = date.year
      installment.paid = date.to_date <= Time.zone.today if new_record? && installment.new_record?
    end
  end

  def validate_noncredit_installments
    return if user_card&.credit? || user_card.blank?

    active_installments = card_installments.reject(&:marked_for_destruction?)
    return if active_installments.one? && active_installments.first.number.to_i == 1

    errors.add(:card_installments, :noncredit_single_installment)
  end

  def prevent_cross_kind_card_change
    errors.add(:user_card, :cross_kind_change) if cross_kind_card_change?
  end

  def cross_kind_card_change?
    return false unless persisted? && will_save_change_to_user_card_id?

    UserCard.find_by(id: user_card_id_in_database)&.card_kind != user_card&.card_kind
  end
end
