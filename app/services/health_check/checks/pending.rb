# frozen_string_literal: true

class HealthCheck::Checks::Pending
  class AdapterUnavailable < StandardError; end

  def initialize(scope:)
    @scope = scope
  end

  def call
    raise AdapterUnavailable, "pending_adapter"
  end
end
