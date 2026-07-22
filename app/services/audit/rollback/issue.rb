# frozen_string_literal: true

Audit::Rollback::Issue = Data.define(:code, :details) do
  def initialize(code:, details: {})
    super(code: code.to_s, details: details.to_h.stringify_keys.sort.to_h)
  end
end
