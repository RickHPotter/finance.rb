# frozen_string_literal: true

module FiscalReceipts
  class IdentityToken
    PURPOSE = "fiscal-receipt-identity"

    def self.issue(user:, access_key:)
      raise ArgumentError, "invalid fiscal access key" unless AccessKey.new(access_key).valid?

      verifier.generate({ "user_id" => user.id, "access_key" => access_key }, purpose: PURPOSE)
    end

    def self.read(token, user:)
      payload = verifier.verified(token, purpose: PURPOSE)
      return unless payload.is_a?(Hash) && payload["user_id"] == user.id

      key = payload["access_key"]
      key if AccessKey.new(key).valid?
    end

    def self.verifier
      Rails.application.message_verifier(:fiscal_receipt_identity)
    end
    private_class_method :verifier
  end
end
