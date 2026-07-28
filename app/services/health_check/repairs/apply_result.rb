# frozen_string_literal: true

HealthCheck::Repairs::ApplyResult = Data.define(
  :status,
  :operation_id,
  :reason_code,
  :duplicate,
  :changed_count,
  :rerun_reason
) do
  def initialize(**attributes)
    attributes.assert_valid_keys(:status, :operation_id, :reason_code, :duplicate, :changed_count, :rerun_reason)
    status = attributes.fetch(:status).to_s
    raise ArgumentError, "invalid apply status" unless status.in?(%w[applied rejected failed])
    raise ArgumentError, "applied result requires an operation ID" if status == "applied" && attributes[:operation_id].blank?

    super(
      status:,
      operation_id: attributes[:operation_id]&.to_s,
      reason_code: attributes[:reason_code]&.to_s,
      duplicate: ActiveModel::Type::Boolean.new.cast(attributes.fetch(:duplicate, false)),
      changed_count: Integer(attributes.fetch(:changed_count, 0)),
      rerun_reason: attributes[:rerun_reason]&.to_s
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

  def duplicate?
    duplicate
  end
end
