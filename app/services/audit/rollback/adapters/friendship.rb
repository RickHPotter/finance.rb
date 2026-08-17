# frozen_string_literal: true

class Audit::Rollback::Adapters::Friendship < Audit::Rollback::Adapters::Base
  def support_issues
    return [] if action.in?(%w[none update])

    [ issue(:unsupported_transaction_graph, attributes: %w[friendship_lifecycle]) ]
  end

  private

  def context_required?
    false
  end
end
