# frozen_string_literal: true

HealthCheck::NamingConventions::ApplyResult = Data.define(
  :status,
  :results,
  :operation_id,
  :reason_code,
  :changed_count
) do
  def initialize(**attributes)
    attributes.assert_valid_keys(:status, :results, :operation_id, :reason_code, :changed_count)
    status = attributes.fetch(:status).to_s
    raise ArgumentError, "invalid naming apply status" unless status.in?(%w[applied rejected failed])

    super(
      status:,
      results: Array(attributes[:results]).freeze,
      operation_id: attributes[:operation_id]&.to_s,
      reason_code: attributes[:reason_code]&.to_s,
      changed_count: Integer(attributes.fetch(:changed_count, 0))
    )
  end

  def applied?
    status == "applied"
  end

  def rejected?
    status == "rejected"
  end

  def failed?
    status == "failed"
  end
end
