# frozen_string_literal: true

module FiscalReceipts
  class AuditIdentity
    PURPOSE = "fiscal-identity-audit"

    def self.encrypt(access_key, user:, context:)
      encryptor.encrypt_and_sign({ "access_key" => access_key, "user_id" => user.id, "context_id" => context.id }, purpose: PURPOSE)
    end

    def self.decrypt(value, user:, context:)
      data = encryptor.decrypt_and_verify(value, purpose: PURPOSE)
      return unless data.is_a?(Hash) && data["user_id"] == user.id && data["context_id"] == context.id

      key = data["access_key"]
      key if AccessKey.new(key).valid?
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def self.encryptor
      key = Rails.application.key_generator.generate_key(PURPOSE, 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
    private_class_method :encryptor
  end
end
