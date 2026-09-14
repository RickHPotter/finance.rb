# frozen_string_literal: true

ReferenceMerges::Result = Data.define(:status, :reason_code, :plan, :operation) do
  def self.applied(operation:, plan: nil)
    new(status: "applied", reason_code: nil, plan:, operation:)
  end

  def self.rejected(reason_code, plan: nil)
    new(status: "rejected", reason_code: reason_code.to_s, plan:, operation: nil)
  end

  def self.failed(reason_code, plan: nil)
    new(status: "failed", reason_code: reason_code.to_s, plan:, operation: nil)
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
