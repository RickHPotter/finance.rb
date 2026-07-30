# frozen_string_literal: true

AllocationMutations::ApplyResult = Data.define(:status, :reason_code, :operation, :impacts, :mode, :duplicate) do
  def initialize(status:, mode:, **attributes)
    status = status.to_s
    raise ArgumentError, "unsupported allocation apply status" unless status.in?(%w[applied rejected failed])

    super(
      status:,
      reason_code: attributes[:reason_code]&.to_s,
      operation: attributes[:operation],
      impacts: Array(attributes[:impacts]).freeze,
      mode: mode.to_s,
      duplicate: ActiveModel::Type::Boolean.new.cast(attributes.fetch(:duplicate, false))
    )
  end

  def applied? = status == "applied"
  def rejected? = status == "rejected"
  def failed? = status == "failed"
  def duplicate? = duplicate
end
