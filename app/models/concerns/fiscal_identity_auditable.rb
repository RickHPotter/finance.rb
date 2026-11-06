# frozen_string_literal: true

module FiscalIdentityAuditable
  extend ActiveSupport::Concern

  included do
    attr_reader :encrypted_fiscal_identity_for_audit

    before_destroy :capture_fiscal_identity_for_audit, prepend: true
  end

  private

  def capture_fiscal_identity_for_audit
    key = fiscal_document_link&.access_key
    @encrypted_fiscal_identity_for_audit = FiscalReceipts::AuditIdentity.encrypt(key, user:, context:) if key.present?
  end
end
