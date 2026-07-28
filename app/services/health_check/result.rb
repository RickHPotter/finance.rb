# frozen_string_literal: true

HealthCheck::Result = Data.define(
  :check_key,
  :outcome,
  :severity,
  :scope,
  :counts,
  :started_at,
  :finished_at,
  :duration_ms,
  :error_code
) do
  def initialize(**attributes)
    attributes.assert_valid_keys(:check_key, :outcome, :severity, :scope, :started_at, :finished_at, :duration_ms, :counts, :error_code)

    check_key = attributes.fetch(:check_key)
    outcome = attributes.fetch(:outcome)
    severity = attributes.fetch(:severity)
    scope = attributes.fetch(:scope)
    started_at = attributes.fetch(:started_at)
    finished_at = attributes.fetch(:finished_at)
    duration_ms = attributes.fetch(:duration_ms)
    counts = attributes.fetch(:counts, {})
    error_code = attributes[:error_code]

    normalized_check_key = check_key.to_s
    normalized_outcome = outcome.to_s
    normalized_severity = severity.to_s
    normalized_error_code = error_code.to_s.presence

    validate_value!(:check_key, normalized_check_key, HealthCheck::Registry.keys)
    validate_value!(:outcome, normalized_outcome, HealthCheck::Vocabulary::OUTCOMES)
    validate_value!(:severity, normalized_severity, HealthCheck::Vocabulary::SEVERITIES)
    validate_times!(started_at, finished_at)
    validate_duration!(duration_ms)
    validate_error_code!(normalized_error_code)

    super(
      check_key: normalized_check_key,
      outcome: normalized_outcome,
      severity: normalized_severity,
      scope: normalize_scope(scope),
      counts: normalize_counts(counts),
      started_at:,
      finished_at:,
      duration_ms:,
      error_code: normalized_error_code
    )
  end

  def healthy?
    outcome == "healthy"
  end

  def warning?
    outcome == "warning"
  end

  def failing?
    outcome == "failing"
  end

  private

  def validate_value!(attribute, value, allowed)
    raise ArgumentError, "invalid #{attribute}" unless value.in?(allowed)
  end

  def normalize_scope(value)
    raise ArgumentError, "invalid scope" unless value.respond_to?(:to_h)

    attributes = value.to_h.symbolize_keys
    allowed_keys = %i[user_id context_id connected_user_id locale]
    raise ArgumentError, "invalid scope" if attributes.keys.difference(allowed_keys).any?
    raise ArgumentError, "invalid scope" unless positive_integer?(attributes[:user_id]) && positive_integer?(attributes[:context_id])
    raise ArgumentError, "invalid scope" unless attributes[:connected_user_id].nil? || positive_integer?(attributes[:connected_user_id])

    locale = attributes.fetch(:locale, I18n.default_locale).to_s
    raise ArgumentError, "invalid scope" unless locale.in?(I18n.available_locales.map(&:to_s))

    attributes.slice(*allowed_keys).merge(locale:).freeze
  end

  def normalize_counts(value)
    raise ArgumentError, "invalid counts" unless value.respond_to?(:to_h)

    attributes = value.to_h.stringify_keys
    raise ArgumentError, "invalid counts" if attributes.keys.difference(HealthCheck::Vocabulary::COUNT_KEYS).any?
    raise ArgumentError, "invalid counts" unless attributes.values.all? { |count| count.is_a?(Integer) && count >= 0 }

    HealthCheck::Vocabulary::COUNT_KEYS.index_with(0).merge(attributes).freeze
  end

  def validate_times!(started_at, finished_at)
    raise ArgumentError, "invalid started_at" unless started_at.respond_to?(:to_time)
    raise ArgumentError, "invalid finished_at" unless finished_at.respond_to?(:to_time)
    raise ArgumentError, "invalid finished_at" if finished_at < started_at
  end

  def validate_duration!(value)
    raise ArgumentError, "invalid duration_ms" unless value.is_a?(Integer) && value >= 0
  end

  def validate_error_code!(value)
    return if value.nil?
    return if value.length <= 100 && value.match?(/\A[a-z0-9_]+\z/)

    raise ArgumentError, "invalid error_code"
  end

  def positive_integer?(value)
    value.is_a?(Integer) && value.positive?
  end
end
