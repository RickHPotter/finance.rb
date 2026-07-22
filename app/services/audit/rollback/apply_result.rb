# frozen_string_literal: true

Audit::Rollback::ApplyResult = Data.define(:status, :operation, :reason_code, :duplicate) do
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
