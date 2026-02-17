# frozen_string_literal: true

module Logic
  class References
    def self.merge(user_card, source_reference_date, target_reference_date)
      source_date = Date.parse(source_reference_date)
      target_date = Date.parse(target_reference_date)

      return false if source_date.prev_month != target_date && source_date.next_month != target_date

      source_card_payment = user_card.unpaid_invoices.find_by(year: source_date.year, month: source_date.month)
      target_card_payment = user_card.unpaid_invoices.find_by(year: target_date.year, month: target_date.month)

      return false if source_card_payment.nil? || target_card_payment.nil?

      # THE PROBLEM LIES RIGHT HERE, MASTER
      source_card_payment.card_installments.update(target_card_payment.slice(:year, :month))

      source_reference = user_card.references.find_by(year: source_date.year, month: source_date.month)
      target_reference = user_card.references.find_by(year: target_date.year, month: target_date.month)

      return false if source_reference.nil? || target_reference.nil?

      target_reference.update_columns(reference_closing_date: source_reference.reference_closing_date)
      source_reference.destroy
    end
  end
end
