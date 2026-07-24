# frozen_string_literal: true

class HealthCheck::Repairs::Preview
  attr_reader :check_key, :repair_key, :scope, :result, :digest, :apply_token

  delegate :finding_id, :state, :changes, :references, :warnings, :paid_history, :unavailable_reason, :previewable?, to: :result

  def initialize(check_key:, repair_key:, scope:, result:)
    @check_key = check_key.to_s
    @repair_key = repair_key.to_s
    @scope = scope
    @result = result

    validate!
    @digest = Digest::SHA256.hexdigest(HealthCheck::Repairs::Payload.canonical_json(digest_payload)).freeze
    @apply_token = HealthCheck::Repairs::PreviewToken.generate(token_payload).freeze
    freeze
  end

  def digest_payload
    {
      check_key:,
      repair_key:,
      scope: scope.to_h.except(:locale),
      result: result.to_h
    }.freeze
  end

  def token_payload
    {
      "actor_id" => scope.user.id,
      "context_id" => scope.context.id,
      "connected_user_id" => scope.connected_user&.id,
      "check_key" => check_key,
      "repair_key" => repair_key,
      "finding_id" => finding_id,
      "digest" => digest
    }.freeze
  end

  private

  def validate!
    entry = HealthCheck::Registry.find(check_key)
    raise ArgumentError, "check is not registered" if entry.blank?
    raise ArgumentError, "repair is not registered for check" unless repair_key.in?(entry.repair_keys)
    raise ArgumentError, "invalid scope" unless scope.is_a?(HealthCheck::Scope)
    raise ArgumentError, "invalid result" unless result.is_a?(HealthCheck::Repairs::Result)
  end
end
