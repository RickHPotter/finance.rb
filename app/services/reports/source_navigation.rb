# frozen_string_literal: true

module Reports
  class SourceNavigation
    attr_reader :record, :installment, :role, :origin, :return_to, :amount_cents

    def initialize(record:, role:, origin:, return_to:, installment: nil, amount_cents: nil)
      @record = record
      @installment = installment
      @role = role
      @origin = origin
      @return_to = return_to
      @amount_cents = amount_cents
    end

    def call
      {
        identity: { record_type: record.class.name, record_id: record.id },
        installment_identity: installment_identity,
        role: role.to_s,
        origin: origin.to_s,
        amount_cents:,
        reference_identity: reference_identity,
        path: record_path
      }.compact
    end

    private

    def installment_identity
      return if installment.blank?

      { record_type: installment.class.name, record_id: installment.id }
    end

    def reference_identity
      return unless record.respond_to?(:reference_transactable_type)
      return if record.reference_transactable_type.blank? || record.reference_transactable_id.blank?

      { record_type: record.reference_transactable_type, record_id: record.reference_transactable_id }
    end

    def record_path
      routes = Rails.application.routes.url_helpers

      case record
      when CashTransaction then routes.cash_transaction_path(record, return_to:)
      when CardTransaction then routes.card_transaction_path(record, return_to:)
      when Investment then routes.investment_path(record, return_to:)
      else raise ArgumentError, "Unsupported report source: #{record.class.name}"
      end
    end
  end
end
