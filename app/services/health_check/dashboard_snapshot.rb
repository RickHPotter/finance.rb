# frozen_string_literal: true

class HealthCheck::DashboardSnapshot
  attr_reader :scope

  def initialize(scope:)
    @scope = scope
  end

  def summaries
    @summaries ||= HealthCheck::Registry.entries.map do |entry|
      entry_scope = scope.for_entry(entry)
      run = runs_by_scope[[ entry.key, entry_scope.connected_user&.id ]]

      HealthCheck::DashboardSummary.new(entry:, run:)
    end.freeze
  end

  private

  def runs_by_scope
    @runs_by_scope ||= HealthCheckRun
                       .where(
                         user_id: scope.user.id,
                         context_id: scope.context.id,
                         connected_user_id: connected_user_ids
                       )
                       .index_by { |run| [ run.check_key, run.connected_user_id ] }
  end

  def connected_user_ids
    HealthCheck::Registry.entries.map { |entry| scope.for_entry(entry).connected_user&.id }.uniq
  end
end
